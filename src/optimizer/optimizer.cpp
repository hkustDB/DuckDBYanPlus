#include "duckdb/optimizer/optimizer.hpp"

#include "duckdb/execution/column_binding_resolver.hpp"
#include "duckdb/function/function_binder.hpp"
#include "duckdb/main/client_context.hpp"
#include "duckdb/main/config.hpp"
#include "duckdb/main/query_profiler.hpp"
#include "duckdb/optimizer/build_probe_side_optimizer.hpp"
#include "duckdb/optimizer/column_lifetime_analyzer.hpp"
#include "duckdb/optimizer/common_aggregate_optimizer.hpp"
#include "duckdb/optimizer/cse_optimizer.hpp"
#include "duckdb/optimizer/cte_filter_pusher.hpp"
#include "duckdb/optimizer/deliminator.hpp"
#include "duckdb/optimizer/empty_result_pullup.hpp"
#include "duckdb/optimizer/expression_heuristics.hpp"
#include "duckdb/optimizer/filter_pullup.hpp"
#include "duckdb/optimizer/filter_pushdown.hpp"
#include "duckdb/optimizer/in_clause_rewriter.hpp"
#include "duckdb/optimizer/join_filter_pushdown_optimizer.hpp"
#include "duckdb/optimizer/join_order/join_order_optimizer.hpp"
#include "duckdb/optimizer/limit_pushdown.hpp"
#include "duckdb/optimizer/regex_range_filter.hpp"
#include "duckdb/optimizer/remove_duplicate_groups.hpp"
#include "duckdb/optimizer/remove_unused_columns.hpp"
#include "duckdb/optimizer/rule/distinct_aggregate_optimizer.hpp"
#include "duckdb/optimizer/rule/equal_or_null_simplification.hpp"
#include "duckdb/optimizer/rule/in_clause_simplification.hpp"
#include "duckdb/optimizer/rule/join_dependent_filter.hpp"
#include "duckdb/optimizer/rule/list.hpp"
#include "duckdb/optimizer/sampling_pushdown.hpp"
#include "duckdb/optimizer/statistics_propagator.hpp"
#include "duckdb/optimizer/sum_rewriter.hpp"
#include "duckdb/optimizer/topn_optimizer.hpp"
#include "duckdb/optimizer/unnest_rewriter.hpp"
#include "duckdb/optimizer/late_materialization.hpp"
#include "duckdb/planner/binder.hpp"
#include "duckdb/planner/planner.hpp"
#include "duckdb/optimizer/predicate_transfer/predicate_transfer_optimizer.hpp"

#include "duckdb/optimizer/setting.hpp"
#include "duckdb/planner/operator/logical_aggregate.hpp"
#include "duckdb/planner/expression/bound_aggregate_expression.hpp"
#include "duckdb/planner/operator/logical_projection.hpp"
#include "duckdb/planner/expression/bound_function_expression.hpp"
#include "duckdb/planner/operator/logical_get.hpp"
#include "duckdb/planner/expression/bound_cast_expression.hpp"
#include "duckdb/planner/expression/bound_columnref_expression.hpp"
#include "duckdb/planner/operator/logical_comparison_join.hpp"


namespace duckdb {

Optimizer::Optimizer(Binder &binder, ClientContext &context) : context(context), binder(binder), rewriter(context) {
	rewriter.rules.push_back(make_uniq<ConstantFoldingRule>(rewriter));
	rewriter.rules.push_back(make_uniq<DistributivityRule>(rewriter));
	rewriter.rules.push_back(make_uniq<ArithmeticSimplificationRule>(rewriter));
	rewriter.rules.push_back(make_uniq<CaseSimplificationRule>(rewriter));
	rewriter.rules.push_back(make_uniq<ConjunctionSimplificationRule>(rewriter));
	rewriter.rules.push_back(make_uniq<DatePartSimplificationRule>(rewriter));
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

	// removes any redundant DelimGets/DelimJoins
	RunOptimizer(OptimizerType::DELIMINATOR, [&]() {
		Deliminator deliminator;
		plan = deliminator.Optimize(std::move(plan));
	});

	// Pulls up empty results
	RunOptimizer(OptimizerType::EMPTY_RESULT_PULLUP, [&]() {
		EmptyResultPullup empty_result_pullup;
		plan = empty_result_pullup.Optimize(std::move(plan));
	});

	RunOptimizer(OptimizerType::IN_CLAUSE, [&]() {
		InClauseRewriter ic_rewriter(context, *this);
		plan = ic_rewriter.Rewrite(std::move(plan));
	});

    auto start_time = std::chrono::high_resolution_clock::now();

    std::cout << "Join order before\n";
    plan->Print();

#ifndef YANPLUS
    RunOptimizer(OptimizerType::JOIN_ORDER, [&]() {
		JoinOrderOptimizer optimizer(context);
		plan = optimizer.Optimize(std::move(plan));
	});
#endif // !YANPLUS

#ifdef YANPLUS
    auto query_type = DetectQueryType(plan.get());
#ifdef PLAN_DEBUG
    std::cout << "Query Type: " << static_cast<int>(query_type) << std::endl;
#endif
    bool GYO = !(query_type == QueryType::OTHER);
#ifdef PLAN_DEBUG
    std::cout << "0. Before Join Order" << std::endl;
    plan->Print();
#endif
    // Step1: do the join ordering
    auto start_time1 = std::chrono::high_resolution_clock::now();

    RunOptimizer(OptimizerType::JOIN_ORDER, [&]() {
		JoinOrderOptimizer optimizer(context, GYO);
        if (GYO) {
            vector<LogicalOperator*> empty_bf_order;
            plan = optimizer.CallSolveJoinOrderFixed(std::move(plan), empty_bf_order);
        }
	});

    auto end_time1 = std::chrono::high_resolution_clock::now();

    // Begin: Keep the copy
    auto plan_original = plan->Copy(context);
    bool is_explain_or_copy = false;
    if (plan->type == LogicalOperatorType::LOGICAL_EXPLAIN || plan->type == LogicalOperatorType::LOGICAL_COPY_TO_FILE) {
        is_explain_or_copy = true;
        plan = std::move(plan->children[0]);
    }
#ifdef PLAN_DEBUG
    std::cout << "1. After Join Order" << std::endl;
    plan->Print();
#endif

    auto start_time2 = std::chrono::high_resolution_clock::now();

    // Step2: specific operation for different query types
	if (query_type == QueryType::SELECT_STAR) {
		PredicateTransferOptimizer PT(context);
		plan = PT.PreOptimize(std::move(plan));
		auto BFOrder = PT.GetBFOrder();
		/*  1. Order debug:  
        std::cout << "BFOrder Size: " << BFOrder.size() << std::endl;
		for (auto &node : BFOrder) {
			std::cout << "BFOrder Node: " << node->ParamsToString() << std::endl;
		}*/
		RunOptimizer(OptimizerType::JOIN_ORDER, [&]() {
			JoinOrderOptimizer optimizer2(context, GYO);
			plan = optimizer2.CallSolveJoinOrderFixed(std::move(plan), BFOrder);
		});
		plan = PT.Optimize(std::move(plan));
        // std::cout << "2.1 select * plan result" << std::endl;
        // plan->Print();
	} else if (query_type == QueryType::COUNT_STAR || query_type == QueryType::MINMAX_AGGREGATE || query_type == QueryType::SUM || query_type == QueryType::SELECT_DISTINCT) {
        unique_ptr<LogicalOperator> plan_copy = plan->Copy(context);
        // Step1: Copy the plan, and record the true agg apply node
		RunOptimizer(OptimizerType::AGGREGATION_PUSHDOWN, [&]() {
			AggregationPushdown aggregation_pushdown(binder, context, query_type);
			plan_copy = aggregation_pushdown.Rewrite(std::move(plan_copy));
		});
        int max_height = DetermineMaxHeight(plan_copy.get());
#ifdef PLAN_DEBUG
        std::cout << "Max Height: " << max_height << std::endl;
        std::cout << "2. Before ApplyAgg without pruning for plan_copy" << std::endl;
        plan_copy->Print();
#endif
        if (query_type != QueryType::SELECT_DISTINCT) {
            for (int i = 0; i < max_height; i++) {
                RunOptimizer(OptimizerType::UNUSED_COLUMNS, [&]() {
                    RemoveUnusedColumns unused(binder, context, true, true);
                    unused.VisitOperator(*plan_copy);
                });
                RunOptimizer(OptimizerType::AGGREGATION_PUSHDOWN, [&]() {
                    AggregationPushdown aggregation_pushdown(binder, context, query_type);
                    plan_copy = aggregation_pushdown.UpdateBinding(std::move(plan_copy));
                });
            }
        } else {
            RunOptimizer(OptimizerType::UNUSED_COLUMNS, [&]() {
                RemoveUnusedColumns unused(binder, context, true, true);
                unused.VisitOperator(*plan_copy);
            });
        }
		
        RunOptimizer(OptimizerType::UNUSED_COLUMNS, [&]() {
            RemoveUnusedColumns unused(binder, context, true);
            unused.VisitOperatorBottomUp(*plan_copy);
        });
#ifdef PLAN_DEBUG
        std::cout << "2.2 plan_copy final result after pruning" << std::endl;
        plan_copy->Print();
#endif
        // Step2: Use the record to apply the real aggre prune to the plan
        RunOptimizer(OptimizerType::AGGREGATION_PUSHDOWN, [&]() {
            AggregationPushdown aggregation_pushdown(binder, context, query_type);
            aggregation_pushdown.RecordAggPushdown(plan_copy);
            plan = aggregation_pushdown.ApplyAgg(std::move(plan));
#ifdef PLAN_DEBUG
            std::cout << "3. After ApplyAgg without pruning " << std::endl;
	        plan->Print();
            PrintOperatorBindings(plan.get());
#endif
        });
        // NOTE: Used for opt-Column Prune
///*
        if (query_type != QueryType::SELECT_DISTINCT) {
            for (int i = 0; i < max_height; i++) {
                RunOptimizer(OptimizerType::UNUSED_COLUMNS, [&]() {
                    RemoveUnusedColumns unused(binder, context, true, true);
                    unused.VisitOperator(*plan);
                });
                RunOptimizer(OptimizerType::AGGREGATION_PUSHDOWN, [&]() {
                    AggregationPushdown aggregation_pushdown(binder, context, query_type);
                    plan = aggregation_pushdown.UpdateBinding(std::move(plan));
                });
            }
        } else {
            RunOptimizer(OptimizerType::UNUSED_COLUMNS, [&]() {
                RemoveUnusedColumns unused(binder, context, true, true);
                unused.VisitOperator(*plan);
            });
        }
        // Fix duplicate column error
        RunOptimizer(OptimizerType::UNUSED_COLUMNS, [&]() {
            RemoveUnusedColumns unused(binder, context, true);
            unused.VisitOperatorBottomUp(*plan);
        });
//*/
#ifdef PLAN_DEBUG
        std::cout << "4. After duplicate fix" << std::endl;
	    plan->Print();
        // PrintOperatorBindings(plan.get());
#endif
	}

    // End: Restore the plan
    if (is_explain_or_copy) {
        plan_original->children[0] = std::move(plan);
        plan = std::move(plan_original);
    }
    auto end_time2 = std::chrono::high_resolution_clock::now();

#endif // YANPLUS

#ifdef PLAN_DEBUG
    std::cout << "5. After whole Agg-Pushdown Plan " << std::endl;
	plan->Print();
    PrintOperatorBindings(plan.get());
#endif

    auto end_time = std::chrono::high_resolution_clock::now();

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

	// pushes LIMIT below PROJECTION
	RunOptimizer(OptimizerType::LIMIT_PUSHDOWN, [&]() {
		LimitPushdown limit_pushdown;
		plan = limit_pushdown.Optimize(std::move(plan));
	});

	// perform sampling pushdown
	RunOptimizer(OptimizerType::SAMPLING_PUSHDOWN, [&]() {
		SamplingPushdown sampling_pushdown;
		plan = sampling_pushdown.Optimize(std::move(plan));
	});

	// transform ORDER BY + LIMIT to TopN
	RunOptimizer(OptimizerType::TOP_N, [&]() {
		TopN topn;
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
    
	std::cout << "6. After All Optimizations Plan " << std::endl;
	plan->Print();
    // PrintOperatorBindings(plan.get());

    auto duration_all = std::chrono::duration_cast<std::chrono::microseconds>(end_time - start_time);
    // auto duration1 = std::chrono::duration_cast<std::chrono::microseconds>(end_time1 - start_time1);
    // auto duration2 = std::chrono::duration_cast<std::chrono::microseconds>(end_time2 - start_time2);
    // std::cout << "Join order time: " << duration1.count() << " microseconds" << std::endl;
    // std::cout << "Agg pushdown & Optimization time: " << duration2.count() << " microseconds" << std::endl;
    std::cout << "All Yan+ optimization time: " << duration_all.count() << " microseconds" << std::endl;
}

unique_ptr<LogicalOperator> Optimizer::Optimize(unique_ptr<LogicalOperator> plan_p) {
    auto start_time = std::chrono::high_resolution_clock::now();

	Verify(*plan_p);

	this->plan = std::move(plan_p);

	for (auto &pre_optimizer_extension : DBConfig::GetConfig(context).optimizer_extensions) {
		RunOptimizer(OptimizerType::EXTENSION, [&]() {
			OptimizerExtensionInput input {GetContext(), *this, pre_optimizer_extension.optimizer_info.get()};
			if (pre_optimizer_extension.pre_optimize_function) {
				pre_optimizer_extension.pre_optimize_function(input, plan);
			}
		});
	}

	RunBuiltInOptimizers();

	for (auto &optimizer_extension : DBConfig::GetConfig(context).optimizer_extensions) {
		RunOptimizer(OptimizerType::EXTENSION, [&]() {
			OptimizerExtensionInput input {GetContext(), *this, optimizer_extension.optimizer_info.get()};
			if (optimizer_extension.optimize_function) {
				optimizer_extension.optimize_function(input, plan);
			}
		});
	}

	Planner::VerifyPlan(context, plan);

    auto end_time = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end_time - start_time);
    // std::cout << "All optimization time: " << duration.count() << " microseconds" << std::endl;

	return std::move(plan);
}

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

bool Optimizer::HasJoins(LogicalOperator* op) {
    // Check if current operator is a join
    if (op->type == LogicalOperatorType::LOGICAL_COMPARISON_JOIN ||
        op->type == LogicalOperatorType::LOGICAL_ASOF_JOIN ||
        op->type == LogicalOperatorType::LOGICAL_DELIM_JOIN ||
        op->type == LogicalOperatorType::LOGICAL_ANY_JOIN ||
        op->type == LogicalOperatorType::LOGICAL_CROSS_PRODUCT) {
        return true;
    }

    // Recursively check children
    for (auto& child : op->children) {
        if (HasJoins(child.get())) {
            return true;
        }
    }

    return false;
}


QueryType Optimizer::DetectQueryType(LogicalOperator* op) {
#ifdef DEBUG
    std::cout << "Print operator type:" << std::endl;
    std::cout << LogicalOperatorToString(op->type) << std::endl;
#endif

    bool has_joins = HasJoins(op);
    if (!op || !has_joins) {
        return QueryType::OTHER;
    }

    if (op->type != LogicalOperatorType::LOGICAL_PROJECTION && op->type != LogicalOperatorType::LOGICAL_DISTINCT) {
        return DetectQueryType(op->children[0].get());
    }

    // Case 2: SELECT COUNT(*) FROM table
    // Usually implemented as a projection over an aggregate
    if (op->type == LogicalOperatorType::LOGICAL_PROJECTION && 
        op->children.size() == 1 && 
        op->children[0]->type == LogicalOperatorType::LOGICAL_AGGREGATE_AND_GROUP_BY) {

        auto& agg = op->children[0]->Cast<LogicalAggregate>();
        auto& expr = agg.expressions[0];
        bool is_count = false;
        bool is_minmax = false;
        bool is_sum = false;

        if (expr->GetExpressionClass() == ExpressionClass::BOUND_AGGREGATE) {
            auto& bound_agg = expr->Cast<BoundAggregateExpression>();
            // Check if this is COUNT(*) or COUNT_STAR
            if (bound_agg.function.name == "count" && !agg.groups.empty()) {
                throw NotImplementedException("count(column) with group by not supported. ");
            } else if (bound_agg.function.name == "count_star" || bound_agg.function.name == "count") {
                if (agg.groups.empty()) {
                    is_count = true;
                } else {
                    is_sum = true;
                }
            }
            if (bound_agg.function.name == "min" || bound_agg.function.name == "max") {
                is_minmax = true;
            }
            if (bound_agg.function.name == "sum") {
                is_sum = true;
            }
        }
        if (is_count) {
            if (is_minmax || is_sum) 
                throw NotImplementedException("Mixed aggregate functions not supported in query type detection.");
            return QueryType::COUNT_STAR;
        } else if (is_minmax) {
            if (is_count || is_sum) 
                throw NotImplementedException("Mixed aggregate functions not supported in query type detection.");
            return QueryType::MINMAX_AGGREGATE;
        } else if (is_sum) {
            if (is_count || is_minmax) 
                throw NotImplementedException("Mixed aggregate functions not supported in query type detection.");
            return QueryType::SUM;
        }
    }

	// Case 4: SELECT distinct a FROM 
    // Usually implemented as a projection over a scan/get
    if (op->type == LogicalOperatorType::LOGICAL_DISTINCT && 
        op->children.size() == 1 && 
        op->children[0]->type == LogicalOperatorType::LOGICAL_PROJECTION) {
        return QueryType::SELECT_DISTINCT;
    }

	// Case 1: SELECT * FROM, full query
    // Usually implemented as a projection over a scan/get
    if (op->type == LogicalOperatorType::LOGICAL_PROJECTION && 
        op->children.size() == 1 && 
        op->children[0]->type != LogicalOperatorType::LOGICAL_AGGREGATE_AND_GROUP_BY){ 
        return QueryType::SELECT_STAR;
    }

    // Any other query pattern
    return QueryType::OTHER;
}

int Optimizer::DetermineMaxHeight(LogicalOperator* op) {
    if (!op) {
        return 0;
    }

    // Find max height among children
    int max_child_height = 0;
    for (auto& child : op->children) {
        int child_height = DetermineMaxHeight(child.get());
        max_child_height = std::max(max_child_height, child_height);
    }

    // Only increment height for join operators
    bool is_join = (op->type == LogicalOperatorType::LOGICAL_COMPARISON_JOIN || 
                    op->type == LogicalOperatorType::LOGICAL_ASOF_JOIN ||
                    op->type == LogicalOperatorType::LOGICAL_DELIM_JOIN ||
                    op->type == LogicalOperatorType::LOGICAL_ANY_JOIN);

    return max_child_height + (is_join ? 1 : 0);
}


void Optimizer::PrintOperatorBindings(LogicalOperator* op, const string& prefix) {
    if (!op) return;

    // First collect all base tables and column_ids mappings from the operator tree
    std::unordered_map<idx_t, std::tuple<string, vector<string>, vector<ColumnIndex>>> table_map;
    std::function<void(const LogicalOperator*)> collect_tables = [&](const LogicalOperator* node) {
        if (!node) return;

        if (node->type == LogicalOperatorType::LOGICAL_GET) {
            auto& get = (const LogicalGet&)(*node);
			string table_name = "table_" + std::to_string(get.table_index);
            table_map[get.table_index] = {std::move(table_name), get.names, get.GetColumnIds()};
        }

        for (auto& child : node->children) {
            collect_tables(child.get());
        }
    };

    collect_tables(op);
    std::cout << "=================================================================" << std::endl;
    // Print operator type
    std::cout << prefix << "Operator: " << LogicalOperatorToString(op->type) << std::endl;

    // Print detailed information for specific operator types
    if (op->type == LogicalOperatorType::LOGICAL_PROJECTION) {
        auto& proj = op->Cast<LogicalProjection>();
        std::cout << prefix << "Projection Expressions: " << std::endl;
        for (idx_t i = 0; i < proj.expressions.size(); i++) {
            auto& expr = proj.expressions[i];
            std::cout << prefix << "  [" << i << "] " << expr->ToString() << " (type: " << expr->return_type.ToString() << ")";
            if (expr->GetName() == "annot") {
                std::cout << " [ANNOT COLUMN]";
            }
            std::cout << std::endl;

            // Print more details for function expressions
            if (expr->type == ExpressionType::BOUND_FUNCTION) {
                auto& func_expr = expr->Cast<BoundFunctionExpression>();
                std::cout << prefix << "    Function: " << func_expr.function.name << std::endl;
                std::cout << prefix << "    Children: " << func_expr.children.size() << std::endl;

                for (idx_t j = 0; j < func_expr.children.size(); j++) {
                    auto& child = func_expr.children[j];
                    std::cout << prefix << "      [" << j << "] " << child->ToString();

                    if (child->type == ExpressionType::BOUND_COLUMN_REF) {
                        auto& col_ref = child->Cast<BoundColumnRefExpression>();
                        std::cout << " (binding: " << col_ref.binding.table_index 
                                  << "." << col_ref.binding.column_index << ")";
                    }
                    std::cout << std::endl;
				}
        	} else if (expr->type == ExpressionType::BOUND_COLUMN_REF) {
				auto& col_ref = expr->Cast<BoundColumnRefExpression>();
				std::cout << " (binding: " << col_ref.binding.table_index 
					  << "." << col_ref.binding.column_index << ")";
			} else if (expr->type == ExpressionType::CAST) {
				auto& cast_expr = expr->Cast<BoundCastExpression>();
				std::cout << " (cast type: " << cast_expr.return_type.ToString() << ")";
			}
			std::cout << std::endl;
        	std::cout << prefix << "Projection Table Index: " << proj.table_index << std::endl;
		}
    }
    else if (op->type == LogicalOperatorType::LOGICAL_AGGREGATE_AND_GROUP_BY) {
        auto& agg = op->Cast<LogicalAggregate>();

        std::cout << prefix << "Group Index: " << agg.group_index << std::endl;
        std::cout << prefix << "Aggregate Index: " << agg.aggregate_index << std::endl;

        // Print group expressions
        std::cout << prefix << "Group Expressions: " << std::endl;
        for (idx_t i = 0; i < agg.groups.size(); i++) {
            auto& expr = agg.groups[i];
            std::cout << prefix << "  [" << i << "] " << expr->ToString() << " (type: " << expr->return_type.ToString() << ")";

            if (expr->type == ExpressionType::BOUND_COLUMN_REF) {
                auto& col_ref = expr->Cast<BoundColumnRefExpression>();
                std::cout << " (binding: " << col_ref.binding.table_index 
                          << "." << col_ref.binding.column_index << ")";
            }
            std::cout << std::endl;
        }

        // Print aggregate expressions
        std::cout << prefix << "Aggregate Expressions: " << std::endl;
        for (idx_t i = 0; i < agg.expressions.size(); i++) {
            auto& expr = agg.expressions[i];
            std::cout << prefix << "  [" << i << "] " << expr->ToString() << " (type: " << expr->return_type.ToString() << ")";
            if (expr->GetName() == "annot") {
                std::cout << " [ANNOT COLUMN]";
            }
            std::cout << std::endl;

            if (expr->type == ExpressionType::BOUND_AGGREGATE) {
                auto& agg_expr = expr->Cast<BoundAggregateExpression>();
                std::cout << prefix << "    Aggregate Function: " << agg_expr.function.name << std::endl;
                std::cout << prefix << "    Children: " << agg_expr.children.size() << std::endl;

                for (idx_t j = 0; j < agg_expr.children.size(); j++) {
                    auto& child = agg_expr.children[j];
                    std::cout << prefix << "      [" << j << "] " << child->ToString();

                    if (child->type == ExpressionType::BOUND_COLUMN_REF) {
                        auto& col_ref = child->Cast<BoundColumnRefExpression>();
                        std::cout << " (binding: " << col_ref.binding.table_index 
                                  << "." << col_ref.binding.column_index << ")";
                    }
                    std::cout << std::endl;
                }
            }
        }
    }
    // If this is a join, print join conditions
    else if (op->type == LogicalOperatorType::LOGICAL_COMPARISON_JOIN) {
        auto& join = op->Cast<LogicalComparisonJoin>();
        // Print left projection map
        std::cout << prefix << "Left Projection Map: ";
        if (!join.left_projection_map.empty()) {
            std::cout << "[";
            for (idx_t i = 0; i < join.left_projection_map.size(); i++) {
                if (i > 0) std::cout << ", ";
                std::cout << join.left_projection_map[i];
            }
            std::cout << "]" << std::endl;
        } else {
            std::cout << "empty (all columns preserved)" << std::endl;
        }

        // Print right projection map
        std::cout << prefix << "Right Projection Map: ";
        if (!join.right_projection_map.empty()) {
            std::cout << "[";
            for (idx_t i = 0; i < join.right_projection_map.size(); i++) {
                if (i > 0) std::cout << ", ";
                std::cout << join.right_projection_map[i];
            }
            std::cout << "]" << std::endl;
        } else {
            std::cout << "empty (all columns preserved)" << std::endl;
        }
        std::cout << prefix << "Join Conditions:" << std::endl;
        for (auto& condition : join.conditions) {
            std::cout << prefix << "  - Left: " << condition.left->ToString() << std::endl;

            if (condition.left->type == ExpressionType::BOUND_COLUMN_REF) {
                auto& left_col = condition.left->Cast<BoundColumnRefExpression>();
                std::cout << prefix << "    Left binding: [" << left_col.binding.table_index 
                          << "." << left_col.binding.column_index << "]" << std::endl;
            }

            std::cout << prefix << "    Right: " << condition.right->ToString() << std::endl;

            if (condition.right->type == ExpressionType::BOUND_COLUMN_REF) {
                auto& right_col = condition.right->Cast<BoundColumnRefExpression>();
                std::cout << prefix << "    Right binding: [" << right_col.binding.table_index 
                          << "." << right_col.binding.column_index << "]" << std::endl;
            }

            std::cout << prefix << "    Comparison: " << EnumUtil::ToChars(condition.comparison) << std::endl;
        }
    }

    // Print column bindings with table info
    auto bindings = op->GetColumnBindings();
    std::cout << prefix << "Column Bindings: " << std::endl;
    for (size_t i = 0; i < bindings.size(); i++) {
        auto& binding = bindings[i];
        std::cout << prefix << "    [" << i << "] " << binding.table_index << "." 
                  << binding.column_index;

        // If this is a table we know about
        if (table_map.find(binding.table_index) != table_map.end()) {
            auto& [table_name, column_names, column_ids] = table_map[binding.table_index];
            std::cout << " (Table: " << table_name;

            // For LogicalGet operators, use column_ids to get the actual column
            if (!column_ids.empty() && binding.column_index < column_ids.size()) {
                // Map binding.column_index to actual column ID
                idx_t actual_col_id = column_ids[binding.column_index].GetPrimaryIndex();

                if (actual_col_id < column_names.size()) {
                    std::cout << ", Column: " << column_names[actual_col_id] 
                              << ", binding.column_index=" << binding.column_index 
                              << " maps to actual column_id=" << actual_col_id;
                }
            } 
            // Fall back to direct binding if not a LogicalGet mapping
            else if (binding.column_index < column_names.size()) {
                std::cout << ", Column: " << column_names[binding.column_index] 
                          << " (direct binding)";
            }
            std::cout << ")";
        } else {
            // This might be a derived table (projection, aggregation, etc.)
            std::cout << " (Derived column)";
        }

        std::cout << std::endl;
    }
    std::cout << "=================================================================" << std::endl;

    // Print children recursively
    for (size_t i = 0; i < op->children.size(); i++) {
        std::cout << prefix << "Child " << i << ":" << std::endl;
        PrintOperatorBindings(op->children[i].get(), prefix + "  ");
    }
}

} // namespace duckdb
