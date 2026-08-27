#include "duckdb/optimizer/join_order/plan_enumerator.hpp"

#include "duckdb/main/client_context.hpp"
#include "duckdb/optimizer/join_order/join_node.hpp"
#include "duckdb/optimizer/join_order/query_graph_manager.hpp"
#include "duckdb/main/settings.hpp"
#include "duckdb/planner/expression/bound_comparison_expression.hpp"

#include <cmath>

namespace duckdb {

static vector<unordered_set<idx_t>> AddSuperSets(const vector<unordered_set<idx_t>> &current,
                                                 const vector<idx_t> &all_neighbors) {
	vector<unordered_set<idx_t>> ret;

	for (const auto &neighbor_set : current) {
		auto max_val = std::max_element(neighbor_set.begin(), neighbor_set.end());
		for (const auto &neighbor : all_neighbors) {
			if (*max_val >= neighbor) {
				continue;
			}
			if (neighbor_set.count(neighbor) == 0) {
				unordered_set<idx_t> new_set;
				for (auto &n : neighbor_set) {
					new_set.insert(n);
				}
				new_set.insert(neighbor);
				ret.push_back(new_set);
			}
		}
	}

	return ret;
}

//! Update the exclusion set with all entries in the subgraph
static void UpdateExclusionSet(optional_ptr<JoinRelationSet> node, unordered_set<idx_t> &exclusion_set) {
	for (idx_t i = 0; i < node->count; i++) {
		exclusion_set.insert(node->relations[i]);
	}
}

// works by first creating all sets with cardinality 1
// then iterates over each previously created group of subsets and will only add a neighbor if the neighbor
// is greater than all relations in the set.
static vector<unordered_set<idx_t>> GetAllNeighborSets(vector<idx_t> neighbors) {
	vector<unordered_set<idx_t>> ret;
	sort(neighbors.begin(), neighbors.end());
	vector<unordered_set<idx_t>> added;
	for (auto &neighbor : neighbors) {
		added.push_back(unordered_set<idx_t>({neighbor}));
		ret.push_back(unordered_set<idx_t>({neighbor}));
	}
	do {
		added = AddSuperSets(added, neighbors);
		for (auto &d : added) {
			ret.push_back(d);
		}
	} while (!added.empty());
#if DEBUG
	// drive by test to make sure we have an accurate amount of
	// subsets, and that each neighbor is in a correct amount
	// of those subsets.
	D_ASSERT(ret.size() == static_cast<size_t>(std::pow(2, neighbors.size())) - 1);
	for (auto &n : neighbors) {
		idx_t count = 0;
		for (auto &set : ret) {
			if (set.count(n) >= 1) {
				count += 1;
			}
		}
		D_ASSERT(count == static_cast<size_t>(std::pow(2, neighbors.size() - 1)));
	}
#endif
	return ret;
}

void PlanEnumerator::GenerateCrossProducts() {
	// generate a set of cross products to combine the currently available plans into a full join plan
	// we create edges between every relation with a high cost
	for (idx_t i = 0; i < query_graph_manager.relation_manager.NumRelations(); i++) {
		auto &left = query_graph_manager.set_manager.GetJoinRelation(i);
		for (idx_t j = 0; j < query_graph_manager.relation_manager.NumRelations(); j++) {
			auto cross_product_allowed = query_graph_manager.relation_manager.CrossProductWithRelationAllowed(i) &&
			                             query_graph_manager.relation_manager.CrossProductWithRelationAllowed(j);
			if (i != j && cross_product_allowed) {
				auto &right = query_graph_manager.set_manager.GetJoinRelation(j);
				query_graph_manager.CreateQueryGraphCrossProduct(left, right);
			}
		}
	}
	// Now that the query graph has new edges, we need to re-initialize our query graph.
	// TODO: do we need to initialize our qyery graph again?
	// query_graph = query_graph_manager.GetQueryGraph();
}

const reference_map_t<JoinRelationSet, unique_ptr<DPJoinNode>> &PlanEnumerator::GetPlans() const {
	return plans;
}

//! Create a new JoinTree node by joining together two previous JoinTree nodes
unique_ptr<DPJoinNode> PlanEnumerator::CreateJoinTree(JoinRelationSet &set,
                                                      const vector<reference<NeighborInfo>> &possible_connections,
                                                      DPJoinNode &left, DPJoinNode &right) {
	// FIXME: should consider different join algorithms, should we pick a join algorithm here as well? (probably)
	optional_ptr<NeighborInfo> best_connection = possible_connections.back().get();
	// cross products are technically still connections, but the filter expression is a null_ptr
	bool found_non_cross_product_connection = false;
	for (auto &connection : possible_connections) {
		for (auto &filter : connection.get().filters) {
			if (filter->join_type != JoinType::INVALID) {
				best_connection = connection.get();
				found_non_cross_product_connection = true;
				break;
			}
		}
		if (found_non_cross_product_connection) {
			break;
		}
	}
	auto join_type = JoinType::INVALID;
	for (auto &filter_binding : best_connection->filters) {
		if (!filter_binding->left_set || !filter_binding->right_set) {
			continue;
		}

		join_type = filter_binding->join_type;
		// prefer joining on semi and anti joins as they have a higher chance of being more
		// selective
		if (join_type == JoinType::SEMI || join_type == JoinType::ANTI) {
			break;
		}
	}
	// need the filter info from the Neighborhood info.
	auto cost = cost_model.ComputeCost(left, right);
	auto result = make_uniq<DPJoinNode>(set, best_connection, left.set, right.set, cost);
	result->cardinality = cost_model.cardinality_estimator.EstimateCardinalityWithSet<idx_t>(set);
	return result;
}

DPJoinNode &PlanEnumerator::EmitPair(JoinRelationSet &left, JoinRelationSet &right,
                                     const vector<reference<NeighborInfo>> &info) {
	// get the left and right join plans
	auto left_plan = plans.find(left);
	auto right_plan = plans.find(right);
	if (left_plan == plans.end() || right_plan == plans.end()) {
		throw InternalException("No left or right plan: internal error in join order optimizer");
	}
	auto &new_set = query_graph_manager.set_manager.Union(left, right);
	// create the join tree based on combining the two plans
	auto new_plan = CreateJoinTree(new_set, info, *left_plan->second, *right_plan->second);
	// check if this plan is the optimal plan we found for this set of relations
	auto entry = plans.find(new_set);
	auto new_cost = new_plan->cost;
	double old_cost = NumericLimits<double>::Maximum();
	if (entry != plans.end()) {
		old_cost = entry->second->cost;
	}
	if (entry == plans.end() || new_cost < old_cost) {
		// the new plan costs less than the old plan. Update our DP table.
		plans[new_set] = std::move(new_plan);
		return *plans[new_set];
	}
	// Create join node from the plan currently in the DP table.
	return *entry->second;
}

bool PlanEnumerator::TryEmitPair(JoinRelationSet &left, JoinRelationSet &right,
                                 const vector<reference<NeighborInfo>> &info) {
	pairs++;
	// If a full plan is created, it's possible a node in the plan gets updated. When this happens, make sure you keep
	// emitting pairs until you emit another final plan. Another final plan is guaranteed to be produced because of
	// our symmetry guarantees.
	if (pairs >= 10000) {
		// when the amount of pairs gets too large we exit the dynamic programming and resort to a greedy algorithm
		// FIXME: simple heuristic currently
		// at 10K pairs stop searching exactly and switch to heuristic
		return false;
	}
	EmitPair(left, right, info);
	return true;
}

bool PlanEnumerator::EmitCSG(JoinRelationSet &node) {
	if (node.count == query_graph_manager.relation_manager.NumRelations()) {
		return true;
	}
	// create the exclusion set as everything inside the subgraph AND anything with members BELOW it
	unordered_set<idx_t> exclusion_set;
	for (idx_t i = 0; i < node.relations[0]; i++) {
		exclusion_set.insert(i);
	}
	UpdateExclusionSet(&node, exclusion_set);
	// find the neighbors given this exclusion set
	auto neighbors = query_graph.GetNeighbors(node, exclusion_set);
	if (neighbors.empty()) {
		return true;
	}

	//! Neighbors should be reversed when iterating over them.
	std::sort(neighbors.begin(), neighbors.end(), std::greater<idx_t>());
	for (idx_t i = 0; i < neighbors.size() - 1; i++) {
		D_ASSERT(neighbors[i] > neighbors[i + 1]);
	}

	// Dphyp paper missing this.
	// Because we are traversing in reverse order, we need to add neighbors whose number is smaller than the current
	// node to exclusion_set
	// This avoids duplicated enumeration
	unordered_set<idx_t> new_exclusion_set = exclusion_set;
	for (idx_t i = 0; i < neighbors.size(); ++i) {
		D_ASSERT(new_exclusion_set.find(neighbors[i]) == new_exclusion_set.end());
		new_exclusion_set.insert(neighbors[i]);
	}

	for (auto neighbor : neighbors) {
		// since the GetNeighbors only returns the smallest element in a list, the entry might not be connected to
		// (only!) this neighbor,  hence we have to do a connectedness check before we can emit it
		auto &neighbor_relation = query_graph_manager.set_manager.GetJoinRelation(neighbor);
		auto connections = query_graph.GetConnections(node, neighbor_relation);
		if (!connections.empty()) {
			if (!TryEmitPair(node, neighbor_relation, connections)) {
				return false;
			}
		}

		if (!EnumerateCmpRecursive(node, neighbor_relation, new_exclusion_set)) {
			return false;
		}

		new_exclusion_set.erase(neighbor);
	}
	return true;
}

bool PlanEnumerator::EnumerateCmpRecursive(JoinRelationSet &left, JoinRelationSet &right,
                                           unordered_set<idx_t> &exclusion_set) {
	// get the neighbors of the second relation under the exclusion set
	auto neighbors = query_graph.GetNeighbors(right, exclusion_set);
	if (neighbors.empty()) {
		return true;
	}

	auto all_subset = GetAllNeighborSets(neighbors);
	vector<reference<JoinRelationSet>> union_sets;
	union_sets.reserve(all_subset.size());
	for (const auto &rel_set : all_subset) {
		auto &neighbor = query_graph_manager.set_manager.GetJoinRelation(rel_set);
		// emit the combinations of this node and its neighbors
		auto &combined_set = query_graph_manager.set_manager.Union(right, neighbor);
		// If combined_set.count == right.count, This means we found a neighbor that has been present before
		// This means we didn't set exclusion_set correctly.
		D_ASSERT(combined_set.count > right.count);
		if (plans.find(combined_set) != plans.end()) {
			auto connections = query_graph.GetConnections(left, combined_set);
			if (!connections.empty()) {
				if (!TryEmitPair(left, combined_set, connections)) {
					return false;
				}
			}
		}
		union_sets.push_back(combined_set);
	}

	unordered_set<idx_t> new_exclusion_set = exclusion_set;
	for (const auto &neighbor : neighbors) {
		new_exclusion_set.insert(neighbor);
	}

	// recursively enumerate the sets
	for (idx_t i = 0; i < union_sets.size(); i++) {
		// updated the set of excluded entries with this neighbor
		if (!EnumerateCmpRecursive(left, union_sets[i], new_exclusion_set)) {
			return false;
		}
	}
	return true;
}

bool PlanEnumerator::EnumerateCSGRecursive(JoinRelationSet &node, unordered_set<idx_t> &exclusion_set) {
	// find neighbors of S under the exclusion set
	auto neighbors = query_graph.GetNeighbors(node, exclusion_set);
	if (neighbors.empty()) {
		return true;
	}

	auto all_subset = GetAllNeighborSets(neighbors);
	vector<reference<JoinRelationSet>> union_sets;
	union_sets.reserve(all_subset.size());
	for (const auto &rel_set : all_subset) {
		auto &neighbor = query_graph_manager.set_manager.GetJoinRelation(rel_set);
		// emit the combinations of this node and its neighbors
		auto &new_set = query_graph_manager.set_manager.Union(node, neighbor);
		D_ASSERT(new_set.count > node.count);
		if (plans.find(new_set) != plans.end()) {
			if (!EmitCSG(new_set)) {
				return false;
			}
		}
		union_sets.push_back(new_set);
	}

	unordered_set<idx_t> new_exclusion_set = exclusion_set;
	for (const auto &neighbor : neighbors) {
		new_exclusion_set.insert(neighbor);
	}

	// recursively enumerate the sets
	for (idx_t i = 0; i < union_sets.size(); i++) {
		// updated the set of excluded entries with this neighbor
		if (!EnumerateCSGRecursive(union_sets[i], new_exclusion_set)) {
			return false;
		}
	}
	return true;
}

bool PlanEnumerator::SolveJoinOrderExactly() {
	// now we perform the actual dynamic programming to compute the final result
	// we enumerate over all the possible pairs in the neighborhood
	for (idx_t i = query_graph_manager.relation_manager.NumRelations(); i > 0; i--) {
		// for every node in the set, we consider it as the start node once
		auto &start_node = query_graph_manager.set_manager.GetJoinRelation(i - 1);
		// emit the start node
		if (!EmitCSG(start_node)) {
			return false;
		}
		// initialize the set of exclusion_set as all the nodes with a number below this
		unordered_set<idx_t> exclusion_set;
		for (idx_t j = 0; j < i; j++) {
			exclusion_set.insert(j);
		}
		// then we recursively search for neighbors that do not belong to the banned entries
		if (!EnumerateCSGRecursive(start_node, exclusion_set)) {
			return false;
		}
	}
	return true;
}

void PlanEnumerator::SolveJoinOrderApproximately() {
	// at this point, we exited the dynamic programming but did not compute the final join order because it took too
	// long instead, we use a greedy heuristic to obtain a join ordering now we use Greedy Operator Ordering to
	// construct the result tree first we start out with all the base relations (the to-be-joined relations)
	vector<reference<JoinRelationSet>> join_relations; // T in the paper
	for (idx_t i = 0; i < query_graph_manager.relation_manager.NumRelations(); i++) {
		join_relations.push_back(query_graph_manager.set_manager.GetJoinRelation(i));
	}
	while (join_relations.size() > 1) {
		// now in every step of the algorithm, we greedily pick the join between the to-be-joined relations that has the
		// smallest cost. This is O(r^2) per step, and every step will reduce the total amount of relations to-be-joined
		// by 1, so the total cost is O(r^3) in the amount of relations
		// long is needed to prevent clang-tidy complaints. (idx_t) cannot be added to an iterator position because it
		// is unsigned.
		idx_t best_left = 0, best_right = 0;
		optional_ptr<DPJoinNode> best_connection;
		for (idx_t i = 0; i < join_relations.size(); i++) {
			auto left = join_relations[i];
			for (idx_t j = i + 1; j < join_relations.size(); j++) {
				auto right = join_relations[j];
				// check if we can connect these two relations
				auto connection = query_graph.GetConnections(left, right);
				if (!connection.empty()) {
					// we can check the cost of this connection
					auto node = EmitPair(left, right, connection);

					// update the DP tree in case a plan created by the DP algorithm uses the node
					// that was potentially just updated by EmitPair. You will get a use-after-free
					// error if future plans rely on the old node that was just replaced.
					// if node in FullPath, then updateDP tree.

					if (!best_connection || node.cost < best_connection->cost) {
						// best pair found so far
						best_connection = &EmitPair(left, right, connection);
						best_left = i;
						best_right = j;
					}
				}
			}
		}
		if (!best_connection) {
			// could not find a connection, but we were not done with finding a completed plan
			// we have to add a cross product; we add it between the two smallest relations
			optional_ptr<DPJoinNode> smallest_plans[2];
			size_t smallest_index[2];
			D_ASSERT(join_relations.size() >= 2);

			// first just add the first two join relations. It doesn't matter the cost as the JOO
			// will swap them on estimated cardinality anyway.
			for (idx_t i = 0; i < 2; i++) {
				optional_ptr<DPJoinNode> current_plan = plans[join_relations[i]];
				smallest_plans[i] = current_plan;
				smallest_index[i] = i;
			}

			// if there are any other join relations that don't have connections
			// add them if they have lower estimated cardinality.
			for (idx_t i = 2; i < join_relations.size(); i++) {
				// get the plan for this relation
				optional_ptr<DPJoinNode> current_plan = plans[join_relations[i]];
				// check if the cardinality is smaller than the smallest two found so far
				for (idx_t j = 0; j < 2; j++) {
					if (!smallest_plans[j] || smallest_plans[j]->cost > current_plan->cost) {
						smallest_plans[j] = current_plan;
						smallest_index[j] = i;
						break;
					}
				}
			}
			if (!smallest_plans[0] || !smallest_plans[1]) {
				throw InternalException("Internal error in join order optimizer");
			}
			D_ASSERT(smallest_plans[0] && smallest_plans[1]);
			D_ASSERT(smallest_index[0] != smallest_index[1]);
			auto &left = smallest_plans[0]->set;
			auto &right = smallest_plans[1]->set;
			// create a cross product edge (i.e. edge with empty filter) between these two sets in the query graph
			query_graph_manager.CreateQueryGraphCrossProduct(left, right);
			// now emit the pair and continue with the algorithm
			auto connections = query_graph.GetConnections(left, right);
			D_ASSERT(!connections.empty());

			best_connection = &EmitPair(left, right, connections);
			best_left = smallest_index[0];
			best_right = smallest_index[1];

			// the code below assumes best_right > best_left
			if (best_left > best_right) {
				std::swap(best_left, best_right);
			}
		}
		// now update the to-be-checked pairs
		// remove left and right, and add the combination

		// important to erase the biggest element first
		// if we erase the smallest element first the index of the biggest element changes
		auto &new_set = query_graph_manager.set_manager.Union(join_relations.at(best_left).get(),
		                                                      join_relations.at(best_right).get());
		D_ASSERT(best_right > best_left);
		join_relations.erase(join_relations.begin() + (int64_t)best_right);
		join_relations.erase(join_relations.begin() + (int64_t)best_left);
		join_relations.push_back(new_set);
	}
}

void PlanEnumerator::InitLeafPlans() {
	// First we initialize each of the single-node plans with themselves and with their cardinalities these are the leaf
	// nodes of the join tree NOTE: we can just use pointers to JoinRelationSet* here because the GetJoinRelation
	// function ensures that a unique combination of relations will have a unique JoinRelationSet object.
	// first initialize equivalent relations based on the filters
	auto relation_stats = query_graph_manager.relation_manager.GetRelationStats();

	cost_model.cardinality_estimator.InitEquivalentRelations(query_graph_manager.GetFilterBindings());
	cost_model.cardinality_estimator.AddRelationNamesToRelationStats(relation_stats);

	// then update the total domains based on the cardinalities of each relation.
	for (idx_t i = 0; i < relation_stats.size(); i++) {
		auto stats = relation_stats.at(i);
		auto &relation_set = query_graph_manager.set_manager.GetJoinRelation(i);
		auto join_node = make_uniq<DPJoinNode>(relation_set);
		join_node->cost = 0;
		join_node->cardinality = stats.cardinality;
		D_ASSERT(join_node->set.count == 1);
		plans[relation_set] = std::move(join_node);
		cost_model.cardinality_estimator.InitCardinalityEstimatorProps(&relation_set, stats);
	}
}

// the plan enumeration is a straight implementation of the paper "Dynamic Programming Strikes Back" by Guido
// Moerkotte and Thomas Neumannn, see that paper for additional info/documentation bonus slides:
// https://db.in.tum.de/teaching/ws1415/queryopt/chapter3.pdf?lang=de
void PlanEnumerator::SolveJoinOrder() {
	bool force_no_cross_product = Settings::Get<DebugForceNoCrossProductSetting>(query_graph_manager.context);
	// first try to solve the join order exactly
	if (query_graph_manager.relation_manager.NumRelations() >= THRESHOLD_TO_SWAP_TO_APPROXIMATE) {
		SolveJoinOrderApproximately();
	} else if (!SolveJoinOrderExactly()) {
		// otherwise, if that times out we resort to a greedy algorithm
		SolveJoinOrderApproximately();
	}

	// now the optimal join path should have been found
	// get it from the node
	unordered_set<idx_t> bindings;
	for (idx_t i = 0; i < query_graph_manager.relation_manager.NumRelations(); i++) {
		bindings.insert(i);
	}
	auto &total_relation = query_graph_manager.set_manager.GetJoinRelation(bindings);
	auto final_plan = plans.find(total_relation);
	if (final_plan == plans.end()) {
		// could not find the final plan
		// this should only happen in case the sets are actually disjunct
		// in this case we need to generate cross product to connect the disjoint sets
		if (force_no_cross_product) {
			throw InvalidInputException(
			    "Query requires a cross-product, but 'force_no_cross_product' PRAGMA is enabled");
		}
		GenerateCrossProducts();
		//! solve the join order again, returning the final plan
		return SolveJoinOrder();
	}
}

void PlanEnumerator::SolveJoinOrderFixed(vector<LogicalOperator *> &exec_order) {
	if (exec_order.empty()) {
		return;
	}

	vector<reference<JoinRelationSet>> join_relations;
	unordered_set<idx_t> included_relations;
	for (auto op : exec_order) {
		if (!op) {
			continue;
		}
		auto table_indexes = op->GetTableIndex();
		if (table_indexes.empty()) {
			continue;
		}
		auto mapping = query_graph_manager.relation_manager.relation_mapping.find(table_indexes[0]);
		if (mapping == query_graph_manager.relation_manager.relation_mapping.end()) {
			continue;
		}
		if (included_relations.insert(mapping->second).second) {
			join_relations.push_back(query_graph_manager.set_manager.GetJoinRelation(mapping->second));
		}
	}

	// A fixed predicate-transfer order should normally contain every relation.
	// Append any missing relations deterministically so reconstruction always
	// receives a complete plan.
	for (idx_t relation_idx = 0; relation_idx < query_graph_manager.relation_manager.NumRelations(); relation_idx++) {
		if (included_relations.insert(relation_idx).second) {
			join_relations.push_back(query_graph_manager.set_manager.GetJoinRelation(relation_idx));
		}
	}
	if (join_relations.empty()) {
		return;
	}

	auto current_set = &join_relations[0].get();
	vector<idx_t> remaining;
	for (idx_t i = 1; i < join_relations.size(); i++) {
		remaining.push_back(i);
	}

	while (!remaining.empty()) {
		idx_t selected = DConstants::INVALID_INDEX;
		vector<reference<NeighborInfo>> selected_connections;
		for (idx_t i = 0; i < remaining.size(); i++) {
			auto &next_set = join_relations[remaining[i]].get();
			auto connections = query_graph.GetConnections(*current_set, next_set);
			if (!connections.empty()) {
				selected = i;
				selected_connections = std::move(connections);
				break;
			}
		}

		if (selected == DConstants::INVALID_INDEX) {
			// Preserve the requested left-deep order even for disconnected
			// components by adding the same explicit cross-product edge used by
			// DuckDB's regular enumerator.
			selected = 0;
			auto &next_set = join_relations[remaining[selected]].get();
			query_graph_manager.CreateQueryGraphCrossProduct(*current_set, next_set);
			selected_connections = query_graph.GetConnections(*current_set, next_set);
		}

		auto &next_set = join_relations[remaining[selected]].get();
		auto left_plan = plans.find(*current_set);
		auto right_plan = plans.find(next_set);
		if (left_plan == plans.end() || right_plan == plans.end() || selected_connections.empty()) {
			throw InternalException("Failed to construct fixed Yan+ join order");
		}
		auto &new_set = query_graph_manager.set_manager.Union(*current_set, next_set);
		plans[new_set] =
		    CreateJoinTree(new_set, selected_connections, *left_plan->second, *right_plan->second);
		current_set = &new_set;
		remaining.erase_at(selected);
	}
}

RelationalHypergraph PlanEnumerator::BuildRelationalHypergraph() {
	RelationalHypergraph graph;
	column_binding_map_t<column_binding_set_t> adjacency;

	for (auto &filter_info : query_graph_manager.GetFilterBindings()) {
		if (!filter_info->filter || filter_info->filter->GetExpressionType() != ExpressionType::COMPARE_EQUAL ||
		    filter_info->filter->GetExpressionClass() != ExpressionClass::BOUND_COMPARISON) {
			continue;
		}
		auto &comparison = filter_info->filter->Cast<BoundComparisonExpression>();
		if (comparison.left->GetExpressionType() != ExpressionType::BOUND_COLUMN_REF ||
		    comparison.right->GetExpressionType() != ExpressionType::BOUND_COLUMN_REF) {
			continue;
		}
		auto left = filter_info->left_binding;
		auto right = filter_info->right_binding;
		if (left.table_index == DConstants::INVALID_INDEX || right.table_index == DConstants::INVALID_INDEX) {
			continue;
		}
		adjacency[left].insert(left);
		adjacency[left].insert(right);
		adjacency[right].insert(left);
		adjacency[right].insert(right);
	}

	column_binding_set_t visited;
	idx_t next_vertex_id = 0;
	for (auto &entry : adjacency) {
		const auto &start = entry.first;
		if (visited.find(start) != visited.end()) {
			continue;
		}

		vector<ColumnBinding> pending;
		pending.push_back(start);
		visited.insert(start);
		vector<ColumnBinding> component;
		while (!pending.empty()) {
			auto binding = pending.back();
			pending.pop_back();
			component.push_back(binding);
			for (auto &neighbor : adjacency[binding]) {
				if (visited.insert(neighbor).second) {
					pending.push_back(neighbor);
				}
			}
		}

		for (auto &binding : component) {
			graph.column_to_vertex[binding] = next_vertex_id;
		}
		next_vertex_id++;
	}

	for (idx_t relation_idx = 0; relation_idx < query_graph_manager.relation_manager.NumRelations(); relation_idx++) {
		unordered_set<idx_t> vertices;
		for (auto &entry : graph.column_to_vertex) {
			if (entry.first.table_index == relation_idx) {
				vertices.insert(entry.second);
			}
		}
		if (!vertices.empty()) {
			graph.relations.push_back(std::move(vertices));
			graph.relation_indices.push_back(relation_idx);
		}
	}
	return graph;
}

vector<idx_t> PlanEnumerator::GetEarWitnesses(RelationalHypergraph &graph, idx_t relation_idx) {
	vector<idx_t> witnesses;
	if (graph.relations.size() == 1) {
		witnesses.push_back(relation_idx);
		return witnesses;
	}

	const auto &relation = graph.relations[relation_idx];
	unordered_set<idx_t> shared_attributes;
	for (auto vertex : relation) {
		for (idx_t other_idx = 0; other_idx < graph.relations.size(); other_idx++) {
			if (other_idx != relation_idx && graph.relations[other_idx].find(vertex) != graph.relations[other_idx].end()) {
				shared_attributes.insert(vertex);
				break;
			}
		}
	}
	if (shared_attributes.empty()) {
		return witnesses;
	}

	for (idx_t other_idx = 0; other_idx < graph.relations.size(); other_idx++) {
		if (other_idx == relation_idx) {
			continue;
		}
		const auto &candidate = graph.relations[other_idx];
		bool contains_shared = true;
		for (auto vertex : shared_attributes) {
			if (candidate.find(vertex) == candidate.end()) {
				contains_shared = false;
				break;
			}
		}
		if (contains_shared) {
			witnesses.push_back(other_idx);
		}
	}
	return witnesses;
}

PlanEnumerator::GYOResult PlanEnumerator::SolveJoinOrderGYO() {
	GYOResult result;
	auto graph = BuildRelationalHypergraph();
	gyo_reduction_sequence.clear();

	const auto total_relations = query_graph_manager.relation_manager.NumRelations();
	if (graph.relations.size() != total_relations || total_relations == 0) {
		return result;
	}
	if (total_relations == 1) {
		InitLeafPlans();
		result.applicable = true;
		result.acyclic = true;
		return result;
	}

	InitLeafPlans();
	unordered_map<idx_t, JoinRelationSet *> relation_to_current_set;
	for (idx_t relation_idx = 0; relation_idx < total_relations; relation_idx++) {
		relation_to_current_set[relation_idx] = &query_graph_manager.set_manager.GetJoinRelation(relation_idx);
	}

	optional_ptr<JoinRelationSet> final_set;
	while (graph.relations.size() > 1) {
		struct EarCandidate {
			idx_t ear_idx;
			idx_t witness_idx;
			double cost;
			unique_ptr<DPJoinNode> join_node;
			JoinRelationSet *union_set;
		};
		vector<EarCandidate> candidates;

		for (idx_t ear_idx = 0; ear_idx < graph.relations.size(); ear_idx++) {
			for (auto witness_idx : GetEarWitnesses(graph, ear_idx)) {
				if (witness_idx == ear_idx) {
					continue;
				}
				auto ear_relation_idx = graph.relation_indices[ear_idx];
				auto witness_relation_idx = graph.relation_indices[witness_idx];
				auto ear_set = relation_to_current_set[ear_relation_idx];
				auto witness_set = relation_to_current_set[witness_relation_idx];
				auto connections = query_graph.GetConnections(*ear_set, *witness_set);
				if (connections.empty()) {
					continue;
				}
				auto ear_plan = plans.find(*ear_set);
				auto witness_plan = plans.find(*witness_set);
				if (ear_plan == plans.end() || witness_plan == plans.end()) {
					continue;
				}
				auto &union_set = query_graph_manager.set_manager.Union(*ear_set, *witness_set);
				auto join_node = CreateJoinTree(union_set, connections, *ear_plan->second, *witness_plan->second);
				candidates.push_back({ear_idx, witness_idx, join_node->cost, std::move(join_node), &union_set});
			}
		}

		if (candidates.empty()) {
			result.applicable = true;
			result.cyclic_core = graph.relation_indices;
			std::sort(result.cyclic_core.begin(), result.cyclic_core.end());
			result.reduction_steps = gyo_reduction_sequence;
			return result;
		}

		auto best = std::min_element(candidates.begin(), candidates.end(), [&](const EarCandidate &left,
		                                                                       const EarCandidate &right) {
			if (left.cost != right.cost) {
				return left.cost < right.cost;
			}
			auto left_relation = graph.relation_indices[left.ear_idx];
			auto right_relation = graph.relation_indices[right.ear_idx];
			if (left_relation != right_relation) {
				return left_relation < right_relation;
			}
			return graph.relation_indices[left.witness_idx] < graph.relation_indices[right.witness_idx];
		});

		auto ear_relation_idx = graph.relation_indices[best->ear_idx];
		auto witness_relation_idx = graph.relation_indices[best->witness_idx];
		gyo_reduction_sequence.push_back({ear_relation_idx, witness_relation_idx});
		plans[*best->union_set] = std::move(best->join_node);

		auto ear_set = relation_to_current_set[ear_relation_idx];
		auto witness_set = relation_to_current_set[witness_relation_idx];
		for (auto &entry : relation_to_current_set) {
			if (entry.second == ear_set || entry.second == witness_set) {
				entry.second = best->union_set;
			}
		}
		if (best->union_set->count == total_relations) {
			final_set = best->union_set;
		}

		graph.relations.erase_at(best->ear_idx);
		graph.relation_indices.erase_at(best->ear_idx);
	}

	if (!final_set || plans.find(*final_set) == plans.end()) {
		return result;
	}
	result.applicable = true;
	result.acyclic = true;
	result.reduction_steps = gyo_reduction_sequence;
	return result;
}

static idx_t CoreRelationCount(const JoinRelationSet &set, const unordered_set<idx_t> &core) {
	idx_t count = 0;
	for (idx_t i = 0; i < set.count; i++) {
		count += core.find(set.relations[i]) != core.end();
	}
	return count;
}

static void CopyRelationSet(const JoinRelationSet &set, vector<idx_t> &target) {
	target.clear();
	target.reserve(set.count);
	for (idx_t i = 0; i < set.count; i++) {
		target.push_back(set.relations[i]);
	}
}

static bool HyperedgesOverlap(const unordered_set<idx_t> &left, const unordered_set<idx_t> &right) {
	for (auto vertex : left) {
		if (right.find(vertex) != right.end()) {
			return true;
		}
	}
	return false;
}

bool PlanEnumerator::BuildTwoCyclicBagPlan(const vector<idx_t> &cyclic_core) {
	// The exact annotation rewrite currently consumes one binary join tree. Keep
	// non-core ears on the established native-DP/GHD path until they can be
	// attached without hiding either cyclic bag behind an arbitrary DP subtree.
	if (cyclic_core.size() != query_graph_manager.relation_manager.NumRelations() || cyclic_core.size() < 5) {
		return false;
	}

	auto graph = BuildRelationalHypergraph();
	if (graph.relations.size() != cyclic_core.size()) {
		return false;
	}

	unordered_map<idx_t, idx_t> relation_position;
	for (idx_t position = 0; position < graph.relation_indices.size(); position++) {
		relation_position[graph.relation_indices[position]] = position;
	}

	auto component_is_cyclic = [&](const vector<idx_t> &component) {
		RelationalHypergraph reduced;
		for (auto relation_idx : component) {
			auto position = relation_position.find(relation_idx);
			if (position == relation_position.end()) {
				return false;
			}
			reduced.relations.push_back(graph.relations[position->second]);
			reduced.relation_indices.push_back(relation_idx);
		}
		while (reduced.relations.size() > 1) {
			bool removed_ear = false;
			for (idx_t relation_idx = 0; relation_idx < reduced.relations.size(); relation_idx++) {
				if (!GetEarWitnesses(reduced, relation_idx).empty()) {
					reduced.relations.erase_at(relation_idx);
					reduced.relation_indices.erase_at(relation_idx);
					removed_ear = true;
					break;
				}
			}
			if (!removed_ear) {
				return true;
			}
		}
		return false;
	};

	auto ordered_core = cyclic_core;
	std::sort(ordered_core.begin(), ordered_core.end());
	for (auto separator_idx : ordered_core) {
		vector<idx_t> remaining;
		for (auto relation_idx : ordered_core) {
			if (relation_idx != separator_idx) {
				remaining.push_back(relation_idx);
			}
		}

		vector<vector<idx_t>> components;
		unordered_set<idx_t> visited;
		for (auto start : remaining) {
			if (!visited.insert(start).second) {
				continue;
			}
			vector<idx_t> component;
			vector<idx_t> pending {start};
			while (!pending.empty()) {
				auto current = pending.back();
				pending.pop_back();
				component.push_back(current);
				auto current_position = relation_position.find(current);
				if (current_position == relation_position.end()) {
					return false;
				}
				for (auto candidate : remaining) {
					if (visited.find(candidate) != visited.end()) {
						continue;
					}
					auto candidate_position = relation_position.find(candidate);
					if (candidate_position != relation_position.end() &&
					    HyperedgesOverlap(graph.relations[current_position->second],
					                      graph.relations[candidate_position->second])) {
						visited.insert(candidate);
						pending.push_back(candidate);
					}
				}
			}
			std::sort(component.begin(), component.end());
			components.push_back(std::move(component));
		}

		if (components.size() != 2 || !component_is_cyclic(components[0]) || !component_is_cyclic(components[1])) {
			continue;
		}
		if (components[1][0] < components[0][0]) {
			std::swap(components[0], components[1]);
		}

		unordered_set<idx_t> left_relations(components[0].begin(), components[0].end());
		unordered_set<idx_t> right_relations(components[1].begin(), components[1].end());
		auto &left_set = query_graph_manager.set_manager.GetJoinRelation(left_relations);
		auto &right_set = query_graph_manager.set_manager.GetJoinRelation(right_relations);
		auto &separator_set = query_graph_manager.set_manager.GetJoinRelation(separator_idx);
		auto left_plan = plans.find(left_set);
		auto right_plan = plans.find(right_set);
		auto separator_plan = plans.find(separator_set);
		if (left_plan == plans.end() || right_plan == plans.end() || separator_plan == plans.end()) {
			continue;
		}

		auto separator_connections = query_graph.GetConnections(left_set, separator_set);
		if (separator_connections.empty()) {
			continue;
		}
		auto &left_with_separator = query_graph_manager.set_manager.Union(left_set, separator_set);
		auto left_with_separator_plan =
		    CreateJoinTree(left_with_separator, separator_connections, *left_plan->second, *separator_plan->second);
		plans[left_with_separator] = std::move(left_with_separator_plan);

		auto final_connections = query_graph.GetConnections(left_with_separator, right_set);
		if (final_connections.empty()) {
			continue;
		}
		auto final_left_plan = plans.find(left_with_separator);
		auto final_right_plan = plans.find(right_set);
		if (final_left_plan == plans.end() || final_right_plan == plans.end()) {
			continue;
		}
		auto &total_set = query_graph_manager.set_manager.Union(left_with_separator, right_set);
		auto total_plan =
		    CreateJoinTree(total_set, final_connections, *final_left_plan->second, *final_right_plan->second);
		plans[total_set] = std::move(total_plan);
		return true;
	}
	return false;
}

bool PlanEnumerator::FindPlanDerivedGHDBoundary(const vector<idx_t> &cyclic_core, VirtualBagBoundary &result) const {
	if (cyclic_core.size() < 2) {
		return false;
	}
	unordered_set<idx_t> core(cyclic_core.begin(), cyclic_core.end());
	unordered_set<idx_t> all_relations;
	for (idx_t relation_idx = 0; relation_idx < query_graph_manager.relation_manager.NumRelations(); relation_idx++) {
		all_relations.insert(relation_idx);
	}
	auto &total_set = query_graph_manager.set_manager.GetJoinRelation(all_relations);
	auto current = plans.find(total_set);
	if (current == plans.end()) {
		return false;
	}

	while (!current->second->is_leaf) {
		auto &node = *current->second;
		auto left_core_count = CoreRelationCount(node.left_set, core);
		auto right_core_count = CoreRelationCount(node.right_set, core);
		if (left_core_count > 0 && right_core_count > 0) {
			CopyRelationSet(node.set, result.relations);
			CopyRelationSet(node.left_set, result.left_relations);
			CopyRelationSet(node.right_set, result.right_relations);
			return true;
		}

		JoinRelationSet *next_set = nullptr;
		if (left_core_count == cyclic_core.size()) {
			next_set = &node.left_set;
		} else if (right_core_count == cyclic_core.size()) {
			next_set = &node.right_set;
		} else {
			return false;
		}
		current = plans.find(*next_set);
		if (current == plans.end()) {
			return false;
		}
	}
	return false;
}

} // namespace duckdb
