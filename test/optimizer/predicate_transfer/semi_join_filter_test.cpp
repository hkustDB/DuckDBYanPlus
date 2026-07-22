#include "catch.hpp"
#include "test_helpers.hpp"

#include "duckdb.hpp"
#include "duckdb/optimizer/predicate_transfer/semi_join_filter.hpp"

using namespace duckdb;

namespace {

static unique_ptr<DataChunk> MakeChunk(const vector<Value> &values) {
	auto result = make_uniq<DataChunk>();
	result->Initialize(Allocator::DefaultAllocator(), {LogicalType::INTEGER}, MaxValue<idx_t>(values.size(), 1));
	result->SetCardinality(values.size());
	for (idx_t row = 0; row < values.size(); row++) {
		result->SetValue(0, row, values[row]);
	}
	return result;
}

static vector<idx_t> Probe(SemiJoinFilter &filter, const DataChunk &chunk) {
	SelectionVector selection(STANDARD_VECTOR_SIZE);
	idx_t count;
	filter.Probe(chunk, {0}, selection, count);
	vector<idx_t> result;
	for (idx_t row = 0; row < count; row++) {
		result.push_back(selection.get_index(row));
	}
	return result;
}

} // namespace

TEST_CASE("Yan+ semi-join filter supports Bloom and exact Hash backends", "[predicate_transfer][semi_join_filter]") {
	DuckDB database(nullptr);
	Connection connection(database);
	auto build = MakeChunk({Value::INTEGER(7), Value::INTEGER(9), Value(LogicalType::INTEGER)});
	auto probe = MakeChunk({Value::INTEGER(7), Value(LogicalType::INTEGER), Value::INTEGER(9)});

	for (auto type : {YanplusSemiJoinFilterType::BLOOM, YanplusSemiJoinFilterType::HASH}) {
		SemiJoinFilter filter(type);
		filter.Initialize(*connection.context, build->size());
		filter.Insert(*build, {0});
		filter.Finalize();
		REQUIRE(filter.IsFinalized());
		REQUIRE(Probe(filter, *probe) == vector<idx_t> {0, 2});
	}
}
