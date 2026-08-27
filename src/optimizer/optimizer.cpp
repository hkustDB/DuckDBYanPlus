#include "duckdb/optimizer/optimizer.hpp"

#include "duckdb/execution/column_binding_resolver.hpp"
#include "duckdb/function/function_binder.hpp"
#include "duckdb/main/client_context.hpp"
#include "duckdb/main/config.hpp"
#include "duckdb/main/query_profiler.hpp"
#include "duckdb/main/settings.hpp"
#include "duckdb/optimizer/build_probe_side_optimizer.hpp"
#include "duckdb/optimizer/column_lifetime_analyzer.hpp"
#include "duckdb/optimizer/common_aggregate_optimizer.hpp"
#include "duckdb/optimizer/cse_optimizer.hpp"
#include "duckdb/optimizer/cte_inlining.hpp"
#include "duckdb/optimizer/cte_filter_pusher.hpp"
#include "duckdb/optimizer/deliminator.hpp"
#include "duckdb/optimizer/empty_result_pullup.hpp"
#include "duckdb/optimizer/expression_heuristics.hpp"
#include "duckdb/optimizer/filter_pullup.hpp"
#include "duckdb/optimizer/filter_pushdown.hpp"
#include "duckdb/optimizer/in_clause_rewriter.hpp"
#include "duckdb/optimizer/join_elimination.hpp"
#include "duckdb/optimizer/join_filter_pushdown_optimizer.hpp"
#include "duckdb/optimizer/join_order/join_order_optimizer.hpp"
#ifdef DUCKDB_YANPLUS
#include "duckdb/optimizer/predicate_transfer/predicate_transfer_optimizer.hpp"
#include "duckdb/optimizer/aggregation_pushdown.hpp"
#endif
#include "duckdb/optimizer/limit_pushdown.hpp"
#include "duckdb/optimizer/regex_range_filter.hpp"
#include "duckdb/optimizer/remove_duplicate_groups.hpp"
#include "duckdb/optimizer/remove_unused_columns.hpp"
#include "duckdb/optimizer/row_group_pruner.hpp"
#include "duckdb/optimizer/rule/distinct_aggregate_optimizer.hpp"
#include "duckdb/optimizer/rule/equal_or_null_simplification.hpp"
#include "duckdb/optimizer/rule/in_clause_simplification.hpp"
#include "duckdb/optimizer/rule/join_dependent_filter.hpp"
#include "duckdb/optimizer/rule/list.hpp"
#include "duckdb/optimizer/sampling_pushdown.hpp"
#include "duckdb/optimizer/statistics_propagator.hpp"
#include "duckdb/optimizer/sum_rewriter.hpp"
#include "duckdb/optimizer/topn_optimizer.hpp"
#include "duckdb/optimizer/topn_window_elimination.hpp"
#include "duckdb/optimizer/unnest_rewriter.hpp"
#include "duckdb/optimizer/late_materialization.hpp"
#include "duckdb/optimizer/common_subplan_optimizer.hpp"
#include "duckdb/optimizer/window_self_join.hpp"
#include "duckdb/optimizer/optimizer_extension.hpp"
#include "duckdb/planner/binder.hpp"
#ifdef DUCKDB_YANPLUS
#include "duckdb/planner/expression/bound_aggregate_expression.hpp"
#include "duckdb/planner/expression/bound_columnref_expression.hpp"
#include "duckdb/planner/expression/bound_comparison_expression.hpp"
#include "duckdb/planner/expression_iterator.hpp"
#include "duckdb/planner/operator/logical_comparison_join.hpp"
#include "duckdb/planner/operator/logical_distinct.hpp"
#endif
#include "duckdb/planner/planner.hpp"

namespace duckdb {

#ifdef DUCKDB_YANPLUS
static bool HasSemiJoinFilterOperator(const LogicalOperator &op) {
	if (op.type == LogicalOperatorType::LOGICAL_CREATE_BF || op.type == LogicalOperatorType::LOGICAL_USE_BF) {
		return true;
	}
	for (auto &child : op.children) {
		if (HasSemiJoinFilterOperator(*child)) {
			return true;
		}
	}
	return false;
}

static bool ContainsLogicalOperator(const LogicalOperator &op, LogicalOperatorType type) {
	if (op.type == type) {
		return true;
	}
	for (auto &child : op.children) {
		if (ContainsLogicalOperator(*child, type)) {
			return true;
		}
	}
	return false;
}

struct YanplusPlanShape {
	idx_t join_count = 0;
	idx_t aggregate_count = 0;
	idx_t projection_count = 0;
};

static bool IsDirectEquality(const JoinCondition &condition) {
	return condition.comparison == ExpressionType::COMPARE_EQUAL &&
	       condition.left->type == ExpressionType::BOUND_COLUMN_REF &&
	       condition.right->type == ExpressionType::BOUND_COLUMN_REF;
}

using YanplusEqualityEdge = pair<ColumnBinding, ColumnBinding>;

static void AddYanplusEqualityEdge(const ColumnBinding &left, const ColumnBinding &right,
                                   vector<YanplusEqualityEdge> &edges) {
	if (left.table_index != right.table_index) {
		edges.emplace_back(left, right);
	}
}

static void AddYanplusEqualityEdges(const Expression &expression, vector<YanplusEqualityEdge> &edges) {
	if (expression.GetExpressionClass() == ExpressionClass::BOUND_COMPARISON &&
	    expression.type == ExpressionType::COMPARE_EQUAL) {
		auto &comparison = expression.Cast<BoundComparisonExpression>();
		if (comparison.left->type == ExpressionType::BOUND_COLUMN_REF &&
		    comparison.right->type == ExpressionType::BOUND_COLUMN_REF) {
			AddYanplusEqualityEdge(comparison.left->Cast<BoundColumnRefExpression>().binding,
			                       comparison.right->Cast<BoundColumnRefExpression>().binding, edges);
		}
	}
	ExpressionIterator::EnumerateChildren(
	    expression, [&](const Expression &child) { AddYanplusEqualityEdges(child, edges); });
}

static void CollectYanplusEqualityEdges(const LogicalOperator &op, vector<YanplusEqualityEdge> &edges) {
	if (op.type == LogicalOperatorType::LOGICAL_FILTER) {
		for (auto &expression : op.expressions) {
			AddYanplusEqualityEdges(*expression, edges);
		}
	} else if (op.type == LogicalOperatorType::LOGICAL_COMPARISON_JOIN) {
		auto &join = op.Cast<LogicalComparisonJoin>();
		for (auto &condition : join.conditions) {
			if (condition.comparison == ExpressionType::COMPARE_EQUAL &&
			    condition.left->type == ExpressionType::BOUND_COLUMN_REF &&
			    condition.right->type == ExpressionType::BOUND_COLUMN_REF) {
				AddYanplusEqualityEdge(condition.left->Cast<BoundColumnRefExpression>().binding,
				                       condition.right->Cast<BoundColumnRefExpression>().binding, edges);
			}
		}
	}
	for (auto &child : op.children) {
		CollectYanplusEqualityEdges(*child, edges);
	}
}

static bool HasYanplusJoinSeparator(const LogicalOperator &op) {
	vector<YanplusEqualityEdge> edges;
	CollectYanplusEqualityEdges(op, edges);
	if (edges.empty()) {
		return false;
	}

	vector<ColumnBinding> bindings;
	auto binding_index = [&](const ColumnBinding &binding) {
		auto entry = std::find(bindings.begin(), bindings.end(), binding);
		if (entry != bindings.end()) {
			return static_cast<idx_t>(entry - bindings.begin());
		}
		bindings.push_back(binding);
		return static_cast<idx_t>(bindings.size() - 1);
	};
	for (auto &edge : edges) {
		binding_index(edge.first);
		binding_index(edge.second);
	}
	vector<idx_t> parent;
	for (idx_t index = 0; index < bindings.size(); index++) {
		parent.push_back(index);
	}
	auto root_of = [&](idx_t node) {
		while (parent[node] != node) {
			node = parent[node];
		}
		return node;
	};
	for (auto &edge : edges) {
		auto left = root_of(binding_index(edge.first));
		auto right = root_of(binding_index(edge.second));
		if (left != right) {
			parent[right] = left;
		}
	}

	vector<idx_t> relation_ids;
	vector<idx_t> variable_roots;
	for (idx_t index = 0; index < bindings.size(); index++) {
		if (std::find(relation_ids.begin(), relation_ids.end(), bindings[index].table_index) == relation_ids.end()) {
			relation_ids.push_back(bindings[index].table_index);
		}
		auto root = root_of(index);
		if (std::find(variable_roots.begin(), variable_roots.end(), root) == variable_roots.end()) {
			variable_roots.push_back(root);
		}
	}
	vector<vector<idx_t>> adjacency(relation_ids.size() + variable_roots.size());
	for (idx_t index = 0; index < bindings.size(); index++) {
		auto relation = static_cast<idx_t>(std::find(relation_ids.begin(), relation_ids.end(),
		                                             bindings[index].table_index) -
		                                       relation_ids.begin());
		auto variable = relation_ids.size() +
		                static_cast<idx_t>(std::find(variable_roots.begin(), variable_roots.end(), root_of(index)) -
		                                   variable_roots.begin());
		if (std::find(adjacency[relation].begin(), adjacency[relation].end(), variable) ==
		    adjacency[relation].end()) {
			adjacency[relation].push_back(variable);
			adjacency[variable].push_back(relation);
		}
	}

	auto relation_components = [&](idx_t omitted) {
		vector<bool> visited(adjacency.size(), false);
		idx_t components = 0;
		for (idx_t relation = 0; relation < relation_ids.size(); relation++) {
			if (relation == omitted || visited[relation]) {
				continue;
			}
			components++;
			vector<idx_t> pending {relation};
			while (!pending.empty()) {
				auto node = pending.back();
				pending.pop_back();
				if (node == omitted || visited[node]) {
					continue;
				}
				visited[node] = true;
				for (auto neighbor : adjacency[node]) {
					if (neighbor != omitted && !visited[neighbor]) {
						pending.push_back(neighbor);
					}
				}
			}
		}
		return components;
	};
	if (relation_components(adjacency.size()) != 1) {
		return false;
	}
	for (idx_t omitted = 0; omitted < adjacency.size(); omitted++) {
		if (relation_components(omitted) > 1) {
			return true;
		}
	}
	return false;
}

static bool InspectYanplusPlanShape(const LogicalOperator &op, YanplusPlanShape &shape) {
	switch (op.type) {
	case LogicalOperatorType::LOGICAL_GET:
		return op.children.empty();
	case LogicalOperatorType::LOGICAL_FILTER:
		if (op.children.size() != 1) {
			return false;
		}
		for (auto &expression : op.expressions) {
			if (expression->IsVolatile()) {
				return false;
			}
		}
		return InspectYanplusPlanShape(*op.children[0], shape);
	case LogicalOperatorType::LOGICAL_PROJECTION:
		if (op.children.size() != 1) {
			return false;
		}
		shape.projection_count++;
		return InspectYanplusPlanShape(*op.children[0], shape);
	case LogicalOperatorType::LOGICAL_AGGREGATE_AND_GROUP_BY: {
		if (op.children.size() != 1 || ++shape.aggregate_count > 1) {
			return false;
		}
		auto &aggregate = op.Cast<LogicalAggregate>();
		// The current Yan+ aggregate rewrite represents one global aggregate.
		// Grouped/GROUPING SETS plans retain DuckDB's native v1.5 path.
		if (!aggregate.groups.empty() || !aggregate.grouping_sets.empty() ||
		    !aggregate.grouping_functions.empty()) {
			return false;
		}
		for (auto &expression : aggregate.expressions) {
			if (expression->GetExpressionClass() != ExpressionClass::BOUND_AGGREGATE) {
				return false;
			}
			auto &bound_aggregate = expression->Cast<BoundAggregateExpression>();
			if (bound_aggregate.IsDistinct() || bound_aggregate.filter || bound_aggregate.order_bys) {
				return false;
			}
		}
		return InspectYanplusPlanShape(*op.children[0], shape);
	}
	case LogicalOperatorType::LOGICAL_COMPARISON_JOIN: {
		if (op.children.size() != 2) {
			return false;
		}
		auto &join = op.Cast<LogicalComparisonJoin>();
		if (join.join_type != JoinType::INNER || !join.expressions.empty()) {
			return false;
		}
		for (auto &condition : join.conditions) {
			if (condition.left->IsVolatile() || condition.right->IsVolatile()) {
				return false;
			}
			// GYO and semi-join key extraction require one binding per side.
			// Keep complex equality operands on DuckDB's native optimizer path;
			// non-equality residual predicates remain valid final checks.
			if (condition.comparison == ExpressionType::COMPARE_EQUAL && !IsDirectEquality(condition)) {
				return false;
			}
		}
		if (std::none_of(join.conditions.begin(), join.conditions.end(), IsDirectEquality)) {
			return false;
		}
		shape.join_count++;
		return InspectYanplusPlanShape(*op.children[0], shape) &&
		       InspectYanplusPlanShape(*op.children[1], shape);
	}
	case LogicalOperatorType::LOGICAL_CROSS_PRODUCT:
		// Filter pushdown can leave a connected cyclic comma-join as a
		// CROSS_PRODUCT plus deterministic equality filters until join ordering.
		// The query-graph builder consumes those filters and reconstructs inner
		// comparison joins before any Yan+ aggregate rewrite is applied.
		if (op.children.size() != 2) {
			return false;
		}
		shape.join_count++;
		return InspectYanplusPlanShape(*op.children[0], shape) &&
		       InspectYanplusPlanShape(*op.children[1], shape);
	default:
		// Windows, set operations, CTEs, delim/outer joins,
		// samples and mutation operators retain DuckDB's native optimizer path.
		return false;
	}
}

static LogicalOperator *GetYanplusQueryBody(LogicalOperator *op) {
	while (op && (op->type == LogicalOperatorType::LOGICAL_EXPLAIN ||
	              op->type == LogicalOperatorType::LOGICAL_COPY_TO_FILE)) {
		if (op->children.size() != 1) {
			return nullptr;
		}
		op = op->children[0].get();
	}
	return op;
}
#endif

Optimizer::Optimizer(Binder &binder, ClientContext &context) : context(context), binder(binder), rewriter(context) {
	rewriter.rules.push_back(make_uniq<ConstantOrderNormalizationRule>(rewriter));
	rewriter.rules.push_back(make_uniq<ConstantFoldingRule>(rewriter));
	rewriter.rules.push_back(make_uniq<DistributivityRule>(rewriter));
	rewriter.rules.push_back(make_uniq<ArithmeticSimplificationRule>(rewriter));
	rewriter.rules.push_back(make_uniq<CaseSimplificationRule>(rewriter));
	rewriter.rules.push_back(make_uniq<ConjunctionSimplificationRule>(rewriter));
	rewriter.rules.push_back(make_uniq<DatePartSimplificationRule>(rewriter));
	rewriter.rules.push_back(make_uniq<DateTruncSimplificationRule>(rewriter));
	rewriter.rules.push_back(make_uniq<ComparisonSimplificationRule>(rewriter));
	rewriter.rules.push_back(make_uniq<InClauseSimplificationRule>(rewriter));
	rewriter.rules.push_back(make_uniq<EqualOrNullSimplification>(rewriter));
	rewriter.rules.push_back(make_uniq<MoveConstantsRule>(rewriter));
	rewriter.rules.push_back(make_uniq<LikeOptimizationRule>(rewriter));
	rewriter.rules.push_back(make_uniq<OrderedAggregateOptimizer>(rewriter));
	rewriter.rules.push_back(make_uniq<DistinctAggregateOptimizer>(rewriter));
	rewriter.rules.push_back(make_uniq<DistinctWindowedOptimizer>(rewriter));
	rewriter.rules.push_back(make_uniq<RegexOptimizationRule>(rewriter));
	rewriter.rules.push_back(make_uniq<EmptyNeedleRemovalRule>(rewriter));
	rewriter.rules.push_back(make_uniq<EnumComparisonRule>(rewriter));
	rewriter.rules.push_back(make_uniq<JoinDependentFilterRule>(rewriter));
	rewriter.rules.push_back(make_uniq<TimeStampComparison>(context, rewriter));

#ifdef DEBUG
	for (auto &rule : rewriter.rules) {
		// root not defined in rule
		D_ASSERT(rule->root);
	}
#endif
}

ClientContext &Optimizer::GetContext() {
	return context;
}

bool Optimizer::OptimizerDisabled(OptimizerType type) {
	return OptimizerDisabled(context, type);
}

bool Optimizer::OptimizerDisabled(ClientContext &context_p, OptimizerType type) {
	auto &config = DBConfig::GetConfig(context_p);
	return config.options.disabled_optimizers.find(type) != config.options.disabled_optimizers.end();
}

void Optimizer::RunOptimizer(OptimizerType type, const std::function<void()> &callback) {
	if (context.IsInterrupted()) {
		throw InterruptException();
	}

	if (OptimizerDisabled(type)) {
		// optimizer is marked as disabled: skip
		return;
	}
	auto &profiler = QueryProfiler::Get(context);
	profiler.StartPhase(MetricsUtils::GetOptimizerMetricByType(type));
	callback();
	profiler.EndPhase();
	if (plan) {
		Verify(*plan);
	}
}

void Optimizer::Verify(LogicalOperator &op) {
	ColumnBindingResolver::Verify(op);
}

void Optimizer::RunBuiltInOptimizers() {
	switch (plan->type) {
	case LogicalOperatorType::LOGICAL_TRANSACTION:
	case LogicalOperatorType::LOGICAL_PRAGMA:
	case LogicalOperatorType::LOGICAL_SET:
	case LogicalOperatorType::LOGICAL_ATTACH:
	case LogicalOperatorType::LOGICAL_UPDATE_EXTENSIONS:
	case LogicalOperatorType::LOGICAL_CREATE_SECRET:
	case LogicalOperatorType::LOGICAL_EXTENSION_OPERATOR:
		// skip optimizing simple & often-occurring plans unaffected by rewrites
		if (plan->children.empty()) {
			return;
		}
		break;
	default:
		break;
	}
	// first we perform expression rewrites using the ExpressionRewriter
	// this does not change the logical plan structure, but only simplifies the expression trees
	RunOptimizer(OptimizerType::EXPRESSION_REWRITER, [&]() { rewriter.VisitOperator(*plan); });

	// try to inline CTEs instead of materialization
	RunOptimizer(OptimizerType::CTE_INLINING, [&]() {
		CTEInlining cte_inlining(*this);
		plan = cte_inlining.Optimize(std::move(plan));
	});

	// Rewrites SUM(x + C) into SUM(x) + C * COUNT(x)
	RunOptimizer(OptimizerType::SUM_REWRITER, [&]() {
		SumRewriterOptimizer optimizer(*this);
		optimizer.Optimize(plan);
	});

	// perform filter pullup
	RunOptimizer(OptimizerType::FILTER_PULLUP, [&]() {
		FilterPullup filter_pullup;
		plan = filter_pullup.Rewrite(std::move(plan));
	});

	// perform filter pushdown
	RunOptimizer(OptimizerType::FILTER_PUSHDOWN, [&]() {
		FilterPushdown filter_pushdown(*this);
		unordered_set<idx_t> top_bindings;
		filter_pushdown.CheckMarkToSemi(*plan, top_bindings);
		plan = filter_pushdown.Rewrite(std::move(plan));
	});

	// derive and push filters into materialized CTEs
	RunOptimizer(OptimizerType::CTE_FILTER_PUSHER, [&]() {
		CTEFilterPusher cte_filter_pusher(*this);
		plan = cte_filter_pusher.Optimize(std::move(plan));
	});

	RunOptimizer(OptimizerType::REGEX_RANGE, [&]() {
		RegexRangeFilter regex_opt;
		plan = regex_opt.Rewrite(std::move(plan));
	});

	RunOptimizer(OptimizerType::IN_CLAUSE, [&]() {
		InClauseRewriter ic_rewriter(context, *this);
		plan = ic_rewriter.Rewrite(std::move(plan));
	});

	// removes any redundant DelimGets/DelimJoins
	RunOptimizer(OptimizerType::DELIMINATOR, [&]() {
		Deliminator deliminator;
		plan = deliminator.Optimize(std::move(plan));
	});

	// try to inline CTEs instead of materialization
	RunOptimizer(OptimizerType::CTE_INLINING, [&]() {
		CTEInlining cte_inlining(*this);
		plan = cte_inlining.Optimize(std::move(plan));
	});

	// Pulls up empty results
	RunOptimizer(OptimizerType::EMPTY_RESULT_PULLUP, [&]() {
		EmptyResultPullup empty_result_pullup;
		plan = empty_result_pullup.Optimize(std::move(plan));
	});

#ifdef DUCKDB_YANPLUS
	// Remember the pre-rewrite shape: a supported-looking self-join produced
	// from a window is still outside the Yan+ relation model.
	auto yanplus_had_window = ContainsLogicalOperator(*plan, LogicalOperatorType::LOGICAL_WINDOW);
#endif

	// Replaces some window computations with self-joins
	RunOptimizer(OptimizerType::WINDOW_SELF_JOIN, [&]() {
		WindowSelfJoinOptimizer window_self_join_optimizer(*this);
		plan = window_self_join_optimizer.Optimize(std::move(plan));
	});

#ifdef DUCKDB_YANPLUS
	// Then perform join ordering. Yan+ uses GYO for acyclic queries and a
	// plan-derived two-bag GHD boundary for cyclic queries. Unsupported query
	// shapes keep DuckDB's native v1.5 optimizer path.
	auto query_type = DetectQueryType(plan.get());
	auto yanplus_enabled = Settings::Get<YanplusEnableSetting>(context) && !yanplus_had_window &&
	                       IsYanplusEligible(plan.get(), query_type);
	bool yanplus_cyclic_query = false;
	bool yanplus_decomposable_count = false;
	bool yanplus_two_cyclic_bag_plan = false;
	if (yanplus_enabled && query_type == QueryType::COUNT_STAR) {
		auto count_body = GetYanplusQueryBody(plan.get());
		yanplus_decomposable_count = count_body && HasYanplusJoinSeparator(*count_body);
	}
	RunOptimizer(OptimizerType::JOIN_ORDER, [&]() {
		if (yanplus_enabled) {
			// CREATE_BF/USE_BF keeps base-table bindings in its filter metadata.
			// COUNT annotation pushdown changes those bindings and therefore cannot
			// safely share the same plan. Decomposable COUNT workloads (Graph Q4)
			// have a bridge between cyclic components and use the exact annotation
			// rewrite over the selected native-DP fallback. A single cyclic core
			// retains its established semi-join-filter path (LSQB Q2).
			JoinOrderOptimizer optimizer(context, true, !yanplus_decomposable_count, yanplus_decomposable_count);
			vector<LogicalOperator *> empty_filter_order;
			plan = optimizer.CallSolveJoinOrderFixed(std::move(plan), empty_filter_order);
			yanplus_cyclic_query = optimizer.DetectedCyclicQuery();
			yanplus_two_cyclic_bag_plan = optimizer.SelectedTwoCyclicBagPlan();
		} else {
			JoinOrderOptimizer optimizer(context);
			plan = optimizer.Optimize(std::move(plan));
		}
	});

	if (yanplus_enabled) {
		// Predicate transfer and aggregate pushdown operate below EXPLAIN/COPY.
		// Move the child out temporarily so the outer operator itself remains the
		// exact v1.5 operator produced by the binder.
		unique_ptr<LogicalOperator> outer_operator;
		if ((plan->type == LogicalOperatorType::LOGICAL_EXPLAIN ||
		     plan->type == LogicalOperatorType::LOGICAL_COPY_TO_FILE) &&
		    plan->children.size() == 1) {
			outer_operator = std::move(plan);
			plan = std::move(outer_operator->children[0]);
		}

		if (query_type == QueryType::SELECT_STAR) {
			// A cyclic plan already contains the single directed bag separator.
			// Running the base-table transfer pass afterwards would flatten/reorder
			// that native DP topology, so only use it for the acyclic GYO path.
			if (!yanplus_cyclic_query && !HasSemiJoinFilterOperator(*plan)) {
				PredicateTransferOptimizer predicate_transfer(context);
				plan = predicate_transfer.PreOptimize(std::move(plan));
				auto filter_order = predicate_transfer.GetBFOrder();
				RunOptimizer(OptimizerType::JOIN_ORDER, [&]() {
					JoinOrderOptimizer fixed_order_optimizer(context, true);
					plan = fixed_order_optimizer.CallSolveJoinOrderFixed(std::move(plan), filter_order);
				});
				plan = predicate_transfer.Optimize(std::move(plan));
			}
		} else if (query_type == QueryType::COUNT_STAR && yanplus_two_cyclic_bag_plan) {
			AggregationPushdown aggregation_pushdown(binder, context, query_type);
			RunOptimizer(OptimizerType::AGGREGATION_PUSHDOWN,
			             [&]() { plan = aggregation_pushdown.ApplyTwoCyclicBagCount(std::move(plan)); });
		} else if ((!yanplus_cyclic_query || (query_type == QueryType::COUNT_STAR && yanplus_decomposable_count)) &&
		           (query_type == QueryType::COUNT_STAR || query_type == QueryType::MINMAX_AGGREGATE ||
		            query_type == QueryType::SUM || query_type == QueryType::SELECT_DISTINCT)) {
			// Cyclic COUNT queries deliberately omit CREATE_BF/USE_BF above, so
			// annotation bindings can be pushed through the full selected join tree.
			// Keep all analysis and rewrite state query-local. Reusing one object is
			// also required because the analysis copy records which join branches
			// should receive partial aggregates before the real plan is rewritten.
			AggregationPushdown aggregation_pushdown(binder, context, query_type);
			auto analysis_plan = plan->Copy(context);
			RunOptimizer(OptimizerType::AGGREGATION_PUSHDOWN, [&]() {
				analysis_plan = aggregation_pushdown.Rewrite(std::move(analysis_plan));
			});

			auto max_height = DetermineMaxHeight(analysis_plan.get());
			if (query_type != QueryType::SELECT_DISTINCT) {
				for (int height = 0; height < max_height; height++) {
					RunOptimizer(OptimizerType::UNUSED_COLUMNS, [&]() {
						RemoveUnusedColumns unused(binder, context, true);
						unused.VisitOperator(*analysis_plan);
					});
					RunOptimizer(OptimizerType::AGGREGATION_PUSHDOWN, [&]() {
						analysis_plan = aggregation_pushdown.UpdateBinding(std::move(analysis_plan));
					});
				}
			} else {
				RunOptimizer(OptimizerType::UNUSED_COLUMNS, [&]() {
					RemoveUnusedColumns unused(binder, context, true, true);
					unused.VisitOperator(*analysis_plan);
				});
			}
			RunOptimizer(OptimizerType::UNUSED_COLUMNS, [&]() {
				RemoveUnusedColumns unused(binder, context, true);
				unused.VisitOperatorBottomUp(*analysis_plan);
			});

			RunOptimizer(OptimizerType::AGGREGATION_PUSHDOWN, [&]() {
				aggregation_pushdown.RecordAggPushdown(analysis_plan);
				plan = aggregation_pushdown.ApplyAgg(std::move(plan));
			});

			if (query_type != QueryType::SELECT_DISTINCT) {
				for (int height = 0; height < max_height; height++) {
					RunOptimizer(OptimizerType::UNUSED_COLUMNS, [&]() {
						RemoveUnusedColumns unused(binder, context, true);
						unused.VisitOperator(*plan);
					});
					RunOptimizer(OptimizerType::AGGREGATION_PUSHDOWN, [&]() {
						plan = aggregation_pushdown.UpdateBinding(std::move(plan));
					});
				}
			} else {
				RunOptimizer(OptimizerType::UNUSED_COLUMNS, [&]() {
					RemoveUnusedColumns unused(binder, context, true, true);
					unused.VisitOperator(*plan);
				});
			}
			RunOptimizer(OptimizerType::UNUSED_COLUMNS, [&]() {
				RemoveUnusedColumns unused(binder, context, true);
				unused.VisitOperatorBottomUp(*plan);
			});
		}

		if (outer_operator) {
			outer_operator->children[0] = std::move(plan);
			plan = std::move(outer_operator);
		}
	}
#else
	// Compile-time origin mode: use DuckDB v1.5's native join-order path.
	RunOptimizer(OptimizerType::JOIN_ORDER, [&]() {
		JoinOrderOptimizer optimizer(context);
		plan = optimizer.Optimize(std::move(plan));
	});
#endif

	RunOptimizer(OptimizerType::JOIN_ELIMINATION, [&]() {
		JoinElimination join_elimination;
		plan = join_elimination.Optimize(std::move(plan));
	});

	// rewrites UNNESTs in DelimJoins by moving them to the projection
	RunOptimizer(OptimizerType::UNNEST_REWRITER, [&]() {
		UnnestRewriter unnest_rewriter;
		plan = unnest_rewriter.Optimize(std::move(plan));
	});

	// removes unused columns
	RunOptimizer(OptimizerType::UNUSED_COLUMNS, [&]() {
		RemoveUnusedColumns unused(binder, context, true);
		unused.VisitOperator(*plan);
	});

	// Remove duplicate groups from aggregates
	RunOptimizer(OptimizerType::DUPLICATE_GROUPS, [&]() {
		RemoveDuplicateGroups remove;
		remove.VisitOperator(*plan);
	});

	// then we extract common subexpressions inside the different operators
	RunOptimizer(OptimizerType::COMMON_SUBEXPRESSIONS, [&]() {
		CommonSubExpressionOptimizer cse_optimizer(binder);
		cse_optimizer.VisitOperator(*plan);
	});

	// creates projection maps so unused columns are projected out early
	RunOptimizer(OptimizerType::COLUMN_LIFETIME, [&]() {
		ColumnLifetimeAnalyzer column_lifetime(*this, *plan, true);
		column_lifetime.VisitOperator(*plan);
	});

	// Once we know the column lifetime, we have more information regarding
	// what relations should be the build side/probe side.
	RunOptimizer(OptimizerType::BUILD_SIDE_PROBE_SIDE, [&]() {
		BuildProbeSideOptimizer build_probe_side_optimizer(context, *plan);
		build_probe_side_optimizer.VisitOperator(*plan);
	});

	// convert common subplans into materialized CTEs
	RunOptimizer(OptimizerType::COMMON_SUBPLAN, [&]() {
		CommonSubplanOptimizer common_subplan_optimizer(*this);
		plan = common_subplan_optimizer.Optimize(std::move(plan));
	});

	// pushes LIMIT below PROJECTION
	RunOptimizer(OptimizerType::LIMIT_PUSHDOWN, [&]() {
		LimitPushdown limit_pushdown;
		plan = limit_pushdown.Optimize(std::move(plan));
	});

	RunOptimizer(OptimizerType::ROW_GROUP_PRUNER, [&]() {
		RowGroupPruner row_group_pruner(context);
		plan = row_group_pruner.Optimize(std::move(plan));
	});

	// perform sampling pushdown
	RunOptimizer(OptimizerType::SAMPLING_PUSHDOWN, [&]() {
		SamplingPushdown sampling_pushdown;
		plan = sampling_pushdown.Optimize(std::move(plan));
	});

	// transform ORDER BY + LIMIT to TopN
	RunOptimizer(OptimizerType::TOP_N, [&]() {
		TopN topn(context);
		plan = topn.Optimize(std::move(plan));
	});

	// try to use late materialization
	RunOptimizer(OptimizerType::LATE_MATERIALIZATION, [&]() {
		LateMaterialization late_materialization(*this);
		plan = late_materialization.Optimize(std::move(plan));
	});

	// perform statistics propagation
	column_binding_map_t<unique_ptr<BaseStatistics>> statistics_map;
	RunOptimizer(OptimizerType::STATISTICS_PROPAGATION, [&]() {
		StatisticsPropagator propagator(*this, *plan);
		propagator.PropagateStatistics(plan);
		statistics_map = propagator.GetStatisticsMap();
	});

	// rewrite row_number window function + filter on row_number to aggregate
	RunOptimizer(OptimizerType::TOP_N_WINDOW_ELIMINATION, [&]() {
		TopNWindowElimination topn_window_elimination(context, *this, &statistics_map);
		plan = topn_window_elimination.Optimize(std::move(plan));
	});

	// remove duplicate aggregates
	RunOptimizer(OptimizerType::COMMON_AGGREGATE, [&]() {
		CommonAggregateOptimizer common_aggregate;
		common_aggregate.VisitOperator(*plan);
	});

	// creates projection maps so unused columns are projected out early
	RunOptimizer(OptimizerType::COLUMN_LIFETIME, [&]() {
		ColumnLifetimeAnalyzer column_lifetime(*this, *plan, true);
		column_lifetime.VisitOperator(*plan);
	});

	// apply simple expression heuristics to get an initial reordering
	RunOptimizer(OptimizerType::REORDER_FILTER, [&]() {
		ExpressionHeuristics expression_heuristics(*this);
		plan = expression_heuristics.Rewrite(std::move(plan));
	});

	// perform join filter pushdown after the dust has settled
	RunOptimizer(OptimizerType::JOIN_FILTER_PUSHDOWN, [&]() {
		JoinFilterPushdownOptimizer join_filter_pushdown(*this);
		join_filter_pushdown.VisitOperator(*plan);
	});
}

unique_ptr<LogicalOperator> Optimizer::Optimize(unique_ptr<LogicalOperator> plan_p) {
	Verify(*plan_p);

	this->plan = std::move(plan_p);

	for (auto &pre_optimizer_extension : OptimizerExtension::Iterate(context)) {
		RunOptimizer(OptimizerType::EXTENSION, [&]() {
			OptimizerExtensionInput input {GetContext(), *this, pre_optimizer_extension.optimizer_info.get()};
			if (pre_optimizer_extension.pre_optimize_function) {
				pre_optimizer_extension.pre_optimize_function(input, plan);
			}
		});
	}

	RunBuiltInOptimizers();

	for (auto &optimizer_extension : OptimizerExtension::Iterate(context)) {
		RunOptimizer(OptimizerType::EXTENSION, [&]() {
			OptimizerExtensionInput input {GetContext(), *this, optimizer_extension.optimizer_info.get()};
			if (optimizer_extension.optimize_function) {
				optimizer_extension.optimize_function(input, plan);
			}
		});
	}

	Planner::VerifyPlan(context, plan);

	return std::move(plan);
}

#ifdef DUCKDB_YANPLUS
bool Optimizer::HasJoins(LogicalOperator *op) {
	if (!op) {
		return false;
	}
	switch (op->type) {
	case LogicalOperatorType::LOGICAL_COMPARISON_JOIN:
	case LogicalOperatorType::LOGICAL_ASOF_JOIN:
	case LogicalOperatorType::LOGICAL_DELIM_JOIN:
	case LogicalOperatorType::LOGICAL_ANY_JOIN:
	case LogicalOperatorType::LOGICAL_CROSS_PRODUCT:
		return true;
	default:
		break;
	}
	for (auto &child : op->children) {
		if (HasJoins(child.get())) {
			return true;
		}
	}
	return false;
}

QueryType Optimizer::DetectQueryType(LogicalOperator *op) {
	op = GetYanplusQueryBody(op);
	if (!op || !HasJoins(op)) {
		return QueryType::OTHER;
	}

	if (op->type == LogicalOperatorType::LOGICAL_DISTINCT && op->children.size() == 1 &&
	    op->children[0]->type == LogicalOperatorType::LOGICAL_PROJECTION) {
		return QueryType::SELECT_DISTINCT;
	}

	if (op->type != LogicalOperatorType::LOGICAL_PROJECTION || op->children.size() != 1) {
		return QueryType::OTHER;
	}
	if (op->children[0]->type != LogicalOperatorType::LOGICAL_AGGREGATE_AND_GROUP_BY) {
		return QueryType::SELECT_STAR;
	}

	auto &aggregate = op->children[0]->Cast<LogicalAggregate>();
	optional_idx category;
	for (auto &expression : aggregate.expressions) {
		if (expression->GetExpressionClass() != ExpressionClass::BOUND_AGGREGATE) {
			return QueryType::OTHER;
		}
		auto &bound_aggregate = expression->Cast<BoundAggregateExpression>();
		QueryType expression_type;
		if (bound_aggregate.function.name == "count_star" || bound_aggregate.function.name == "count") {
			expression_type = aggregate.groups.empty() ? QueryType::COUNT_STAR : QueryType::SUM;
		} else if (bound_aggregate.function.name == "min" || bound_aggregate.function.name == "max") {
			expression_type = QueryType::MINMAX_AGGREGATE;
		} else if (bound_aggregate.function.name == "sum") {
			expression_type = QueryType::SUM;
		} else {
			return QueryType::OTHER;
		}
		auto encoded = static_cast<idx_t>(expression_type);
		if (category.IsValid() && category.GetIndex() != encoded) {
			// The current aggregate pushdown implementation intentionally handles
			// one aggregate family at a time. Mixed families fall back safely.
			return QueryType::OTHER;
		}
		category = optional_idx(encoded);
	}
	return category.IsValid() ? static_cast<QueryType>(category.GetIndex()) : QueryType::OTHER;
}

bool Optimizer::IsYanplusEligible(LogicalOperator *op, QueryType query_type) {
	if (query_type == QueryType::OTHER) {
		return false;
	}
	op = GetYanplusQueryBody(op);
	if (!op) {
		return false;
	}
	if (query_type == QueryType::SELECT_DISTINCT) {
		if (op->type != LogicalOperatorType::LOGICAL_DISTINCT || op->children.size() != 1 ||
		    op->children[0]->type != LogicalOperatorType::LOGICAL_PROJECTION) {
			return false;
		}
		auto &distinct = op->Cast<LogicalDistinct>();
		if (distinct.distinct_type != DistinctType::DISTINCT || distinct.order_by) {
			return false;
		}
		op = op->children[0].get();
	}
	if (op->type != LogicalOperatorType::LOGICAL_PROJECTION || op->children.size() != 1) {
		return false;
	}
	if (query_type == QueryType::SELECT_DISTINCT) {
		// Partial DISTINCT is only valid when the result columns preserve the
		// child's equality semantics. Computed and volatile expressions retain
		// DuckDB's native plan (e.g., random() must still run once per join row).
		for (auto &expression : op->expressions) {
			if (expression->GetExpressionClass() != ExpressionClass::BOUND_COLUMN_REF) {
				return false;
			}
		}
	}

	auto aggregate_query = query_type == QueryType::COUNT_STAR || query_type == QueryType::MINMAX_AGGREGATE ||
	                       query_type == QueryType::SUM;
	if (aggregate_query !=
	    (op->children[0]->type == LogicalOperatorType::LOGICAL_AGGREGATE_AND_GROUP_BY)) {
		return false;
	}
	if (aggregate_query && op->children[0]->Cast<LogicalAggregate>().expressions.size() != 1) {
		return false;
	}

	YanplusPlanShape shape;
	if (!InspectYanplusPlanShape(*op, shape) || shape.join_count == 0 || shape.projection_count != 1) {
		return false;
	}
	return aggregate_query ? shape.aggregate_count == 1 : shape.aggregate_count == 0;
}

int Optimizer::DetermineMaxHeight(LogicalOperator *op) {
	if (!op) {
		return 0;
	}
	int child_height = 0;
	for (auto &child : op->children) {
		child_height = std::max(child_height, DetermineMaxHeight(child.get()));
	}
	bool is_join = op->type == LogicalOperatorType::LOGICAL_COMPARISON_JOIN ||
	               op->type == LogicalOperatorType::LOGICAL_ASOF_JOIN ||
	               op->type == LogicalOperatorType::LOGICAL_DELIM_JOIN ||
	               op->type == LogicalOperatorType::LOGICAL_ANY_JOIN ||
	               op->type == LogicalOperatorType::LOGICAL_CROSS_PRODUCT;
	return child_height + (is_join ? 1 : 0);
}
#endif

unique_ptr<Expression> Optimizer::BindScalarFunction(const string &name, unique_ptr<Expression> c1) {
	vector<unique_ptr<Expression>> children;
	children.push_back(std::move(c1));
	return BindScalarFunction(name, std::move(children));
}

unique_ptr<Expression> Optimizer::BindScalarFunction(const string &name, unique_ptr<Expression> c1,
                                                     unique_ptr<Expression> c2) {
	vector<unique_ptr<Expression>> children;
	children.push_back(std::move(c1));
	children.push_back(std::move(c2));
	return BindScalarFunction(name, std::move(children));
}

unique_ptr<Expression> Optimizer::BindScalarFunction(const string &name, vector<unique_ptr<Expression>> children) {
	FunctionBinder binder(context);
	ErrorData error;
	auto expr = binder.BindScalarFunction(DEFAULT_SCHEMA, name, std::move(children), error);
	if (error.HasError()) {
		throw InternalException("Optimizer exception - failed to bind function %s: %s", name, error.Message());
	}
	return expr;
}

} // namespace duckdb
