#include "duckdb/optimizer/join_order/join_order_optimizer.hpp"

#include "duckdb/common/enums/join_type.hpp"
#include "duckdb/common/limits.hpp"
#include "duckdb/common/pair.hpp"
#include "duckdb/optimizer/join_order/cost_model.hpp"
#include "duckdb/optimizer/join_order/plan_enumerator.hpp"
#include "duckdb/planner/expression/list.hpp"
#include "duckdb/planner/operator/list.hpp"
#include "duckdb/main/settings.hpp"

namespace duckdb {

JoinOrderOptimizer::JoinOrderOptimizer(ClientContext &context, bool GYO)
    : context(context), query_graph_manager(context), GYO(GYO), depth(1) {
}

JoinOrderOptimizer JoinOrderOptimizer::CreateChildOptimizer() {
	JoinOrderOptimizer child_optimizer(context, GYO);
	child_optimizer.materialized_cte_stats = materialized_cte_stats;
	child_optimizer.delim_scan_stats = delim_scan_stats;
	child_optimizer.depth = depth + 1;
	child_optimizer.recursive_cte_indexes = recursive_cte_indexes;
	return child_optimizer;
}

unique_ptr<LogicalOperator> JoinOrderOptimizer::Optimize(unique_ptr<LogicalOperator> plan,
                                                         optional_ptr<RelationStats> stats) {
	auto max_expression_depth = Settings::Get<MaxExpressionDepthSetting>(query_graph_manager.context);
	if (depth > max_expression_depth) {
		// Very deep plans will eventually consume quite some stack space
		// Returning the current plan is always a valid choice
		return plan;
	}

	// make sure query graph manager has not extracted a relation graph already
	LogicalOperator *op = plan.get();

	// extract the relations that go into the hyper graph.
	// We optimize the children of any non-reorderable operations we come across.
	bool reorderable = query_graph_manager.Build(*this, *op);

	// get relation_stats here since the reconstruction process will move all relations.
	auto relation_stats = query_graph_manager.relation_manager.GetRelationStats();
	unique_ptr<LogicalOperator> new_logical_plan = nullptr;

	if (reorderable) {
		// query graph now has filters and relations
		auto cost_model = CostModel(query_graph_manager);

		// Initialize a plan enumerator.
		auto plan_enumerator =
		    PlanEnumerator(query_graph_manager, cost_model, query_graph_manager.GetQueryGraphEdges());

		// Initialize the leaf/single node plans
		plan_enumerator.InitLeafPlans();
		plan_enumerator.SolveJoinOrder();
		// now reconstruct a logical plan from the query graph plan
		query_graph_manager.plans = &plan_enumerator.GetPlans();

		new_logical_plan = query_graph_manager.Reconstruct(std::move(plan));
	} else {
		new_logical_plan = std::move(plan);
		if (relation_stats.size() == 1) {
			new_logical_plan->estimated_cardinality = relation_stats.at(0).cardinality;
			new_logical_plan->has_estimated_cardinality = true;
		}
	}

	// Propagate up a stats object from the top of the new_logical_plan if stats exist.
	if (stats) {
		auto cardinality = new_logical_plan->EstimateCardinality(context);
		auto bindings = new_logical_plan->GetColumnBindings();
		auto new_stats = RelationStatisticsHelper::CombineStatsOfReorderableOperator(bindings, relation_stats);
		new_stats.cardinality = cardinality;
		RelationStatisticsHelper::CopyRelationStats(*stats, new_stats);
	} else {
		// starts recursively setting cardinality
		new_logical_plan->EstimateCardinality(context);
	}

	if (new_logical_plan->type == LogicalOperatorType::LOGICAL_EXPLAIN) {
		new_logical_plan->SetEstimatedCardinality(3);
	}

	return new_logical_plan;
}

void JoinOrderOptimizer::AddMaterializedCTEStats(idx_t index, RelationStats &&stats) {
	materialized_cte_stats.emplace(index, std::move(stats));
}

RelationStats JoinOrderOptimizer::GetMaterializedCTEStats(idx_t index) {
	auto it = materialized_cte_stats.find(index);
	if (it == materialized_cte_stats.end()) {
		throw InternalException("Unable to find materialized CTE stats with index %llu", index);
	}
	return it->second;
}

void JoinOrderOptimizer::AddDelimScanStats(RelationStats &stats) {
	delim_scan_stats = &stats;
}

RelationStats JoinOrderOptimizer::GetDelimScanStats() {
	if (!delim_scan_stats) {
		throw InternalException("Unable to find delim scan stats!");
	}
	return *delim_scan_stats;
}

unique_ptr<LogicalOperator>
JoinOrderOptimizer::CallSolveJoinOrderFixed(unique_ptr<LogicalOperator> plan,
	                                         vector<LogicalOperator *> &exec_order) {
	auto plan_backup = plan->Copy(context);
	auto op = plan.get();
	if (!query_graph_manager.Build(*this, *op, false)) {
		JoinOrderOptimizer fallback_optimizer(context);
		return fallback_optimizer.Optimize(std::move(plan_backup));
	}

	try {
		if (!exec_order.empty()) {
			auto cost_model = CostModel(query_graph_manager);
			auto enumerator =
			    PlanEnumerator(query_graph_manager, cost_model, query_graph_manager.GetQueryGraphEdges());
			enumerator.InitLeafPlans();
			enumerator.SolveJoinOrderFixed(exec_order);
			query_graph_manager.plans = &enumerator.GetPlans();
			return query_graph_manager.Reconstruct(std::move(plan));
		}

		if (GYO) {
			// The GYO enumerator remains the source of the acyclic Yan+ plan.
			// If reduction stops on a cyclic core, discard its partial DP table
			// and reconstruct from a separate, ordinary DuckDB v1.5 enumerator.
			auto gyo_cost_model = CostModel(query_graph_manager);
			auto gyo_enumerator =
			    PlanEnumerator(query_graph_manager, gyo_cost_model, query_graph_manager.GetQueryGraphEdges());
			gyo_enumerator.root_op = op;
			auto gyo_result = gyo_enumerator.SolveJoinOrderGYO();
			if (gyo_result.applicable && gyo_result.acyclic) {
				query_graph_manager.plans = &gyo_enumerator.GetPlans();
				return query_graph_manager.Reconstruct(std::move(plan));
			}
			detected_cyclic_query = gyo_result.IsCyclic();

			auto native_cost_model = CostModel(query_graph_manager);
			auto native_enumerator =
			    PlanEnumerator(query_graph_manager, native_cost_model, query_graph_manager.GetQueryGraphEdges());
			native_enumerator.InitLeafPlans();
			native_enumerator.SolveJoinOrder();
			if (gyo_result.IsCyclic() && Settings::Get<YanplusCyclicBagsSetting>(context)) {
				VirtualBagBoundary boundary;
				if (native_enumerator.FindPlanDerivedGHDBoundary(gyo_result.cyclic_core, boundary)) {
					query_graph_manager.SetVirtualBagBoundary(std::move(boundary));
				}
			}
			query_graph_manager.plans = &native_enumerator.GetPlans();
			auto result = query_graph_manager.Reconstruct(std::move(plan));
			inserted_plan_derived_ghd_bag = query_graph_manager.InsertedVirtualBagFilter();
			return result;
		}
	} catch (const NotImplementedException &) {
		// The copied tree has not participated in relation extraction or
		// reconstruction, so a deliberately unsupported Yan+ case can use a
		// fresh native optimizer. Interrupts, resource failures, and internal
		// errors must propagate instead of being silently retried.
	}

	JoinOrderOptimizer fallback_optimizer(context);
	return fallback_optimizer.Optimize(std::move(plan_backup));
}

} // namespace duckdb
