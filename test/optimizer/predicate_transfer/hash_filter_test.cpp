#include "catch.hpp"
#include "test_helpers.hpp"

#include "duckdb/optimizer/predicate_transfer/hash_filter.hpp"

using namespace duckdb;

namespace {

static unique_ptr<DataChunk> MakeIntegerChunk(const vector<Value> &values) {
	auto result = make_uniq<DataChunk>();
	result->Initialize(Allocator::DefaultAllocator(), {LogicalType::INTEGER}, MaxValue<idx_t>(values.size(), 1));
	result->SetCardinality(values.size());
	for (idx_t row = 0; row < values.size(); row++) {
		result->SetValue(0, row, values[row]);
	}
	return result;
}

static unique_ptr<DataChunk> MakeCompositeChunk(const vector<int32_t> &integers, const vector<Value> &strings) {
	auto result = make_uniq<DataChunk>();
	result->Initialize(Allocator::DefaultAllocator(), {LogicalType::INTEGER, LogicalType::VARCHAR},
	                   MaxValue<idx_t>(integers.size(), 1));
	result->SetCardinality(integers.size());
	for (idx_t row = 0; row < integers.size(); row++) {
		result->SetValue(0, row, Value::INTEGER(integers[row]));
		result->SetValue(1, row, strings[row]);
	}
	return result;
}

} // namespace

TEST_CASE("Yan+ exact hash filter handles duplicates and NULL", "[predicate_transfer][hash_filter]") {
	HashFilter filter;
	auto build =
	    MakeIntegerChunk({Value::INTEGER(1), Value::INTEGER(1), Value(LogicalType::INTEGER), Value::INTEGER(3)});
	filter.Build(*build, {0});
	filter.Finalize();

	REQUIRE(filter.IsFinalized());
	REQUIRE(filter.IsInline());
	REQUIRE(filter.Count() == 2);

	auto probe =
	    MakeIntegerChunk({Value::INTEGER(3), Value::INTEGER(2), Value(LogicalType::INTEGER), Value::INTEGER(1)});
	SelectionVector result(STANDARD_VECTOR_SIZE);
	idx_t result_count;
	filter.Probe(*probe, {0}, result, result_count);
	REQUIRE(result_count == 2);
	REQUIRE(result.get_index(0) == 0);
	REQUIRE(result.get_index(1) == 3);
}

TEST_CASE("Yan+ exact hash filter compares composite keys after hash collisions", "[predicate_transfer][hash_filter]") {
	HashFilter filter;
	auto build = MakeCompositeChunk({1, 1, 2}, {Value("a"), Value("b"), Value("a")});
	filter.Build(*build, {0, 1});
	filter.Finalize();

	REQUIRE_FALSE(filter.IsInline());
	REQUIRE(filter.Count() == 3);
	auto probe = MakeCompositeChunk({1, 2, 2, 1}, {Value("a"), Value("b"), Value("a"), Value("c")});
	SelectionVector result(STANDARD_VECTOR_SIZE);
	idx_t result_count;
	filter.Probe(*probe, {0, 1}, result, result_count);
	REQUIRE(result_count == 2);
	REQUIRE(result.get_index(0) == 0);
	REQUIRE(result.get_index(1) == 2);
}
