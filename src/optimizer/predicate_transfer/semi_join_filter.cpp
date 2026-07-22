#include "duckdb/optimizer/predicate_transfer/semi_join_filter.hpp"

#include "duckdb/common/exception.hpp"
#include "duckdb/common/vector_operations/vector_operations.hpp"
#include "duckdb/optimizer/predicate_transfer/hash_filter.hpp"
#include "duckdb/planner/filter/bloom_filter.hpp"

namespace duckdb {

namespace {

static Vector SemiJoinComputeHashes(const DataChunk &chunk, const vector<idx_t> &column_ids) {
	if (column_ids.empty()) {
		throw InternalException("SemiJoinFilter requires at least one key column");
	}
	const auto count = chunk.size();
	Vector hashes(LogicalType::HASH);
	auto &first = const_cast<Vector &>(chunk.data[column_ids[0]]);
	VectorOperations::Hash(first, hashes, count);
	for (idx_t column_idx = 1; column_idx < column_ids.size(); column_idx++) {
		auto &column = const_cast<Vector &>(chunk.data[column_ids[column_idx]]);
		VectorOperations::CombineHash(hashes, column, count);
	}
	if (hashes.GetVectorType() == VectorType::CONSTANT_VECTOR) {
		hashes.Flatten(count);
	}
	return hashes;
}

static bool HasNullKey(const vector<UnifiedVectorFormat> &formats, idx_t row) {
	for (auto &format : formats) {
		if (!format.validity.RowIsValid(format.sel->get_index(row))) {
			return true;
		}
	}
	return false;
}

} // namespace

SemiJoinFilter::SemiJoinFilter(YanplusSemiJoinFilterType type_p) : type(type_p) {
	switch (type) {
	case YanplusSemiJoinFilterType::BLOOM:
		bloom_filter = make_uniq<BloomFilter>();
		break;
	case YanplusSemiJoinFilterType::HASH:
		hash_filter = make_uniq<HashFilter>();
		break;
	default:
		throw InternalException("Unknown Yan+ semi-join filter type");
	}
}

SemiJoinFilter::~SemiJoinFilter() = default;

const char *SemiJoinFilter::GetTypeName() const {
	return type == YanplusSemiJoinFilterType::BLOOM ? "BLOOM" : "HASH";
}

void SemiJoinFilter::Initialize(ClientContext &context, idx_t expected_rows) {
	if (initialized) {
		throw InternalException("SemiJoinFilter initialized more than once");
	}
	if (type == YanplusSemiJoinFilterType::BLOOM) {
		bloom_filter->Initialize(context, expected_rows);
	}
	initialized = true;
}

void SemiJoinFilter::Insert(const DataChunk &chunk, const vector<idx_t> &build_col_ids) {
	if (!initialized || finalized) {
		throw InternalException("SemiJoinFilter insert outside its build phase");
	}
	if (type == YanplusSemiJoinFilterType::HASH) {
		hash_filter->Build(chunk, build_col_ids);
		return;
	}
	auto hashes = SemiJoinComputeHashes(chunk, build_col_ids);
	bloom_filter->InsertHashes(hashes, chunk.size());
}

void SemiJoinFilter::Finalize() {
	if (!initialized || finalized) {
		throw InternalException("SemiJoinFilter finalized in an invalid state");
	}
	if (type == YanplusSemiJoinFilterType::HASH) {
		hash_filter->Finalize();
	}
	finalized = true;
}

void SemiJoinFilter::Probe(const DataChunk &chunk, const vector<idx_t> &probe_col_ids, SelectionVector &result,
                           idx_t &result_count) const {
	if (!finalized) {
		throw InternalException("SemiJoinFilter probed before Finalize");
	}
	if (type == YanplusSemiJoinFilterType::HASH) {
		hash_filter->Probe(chunk, probe_col_ids, result, result_count);
		return;
	}

	auto hashes = SemiJoinComputeHashes(chunk, probe_col_ids);
	vector<UnifiedVectorFormat> formats(probe_col_ids.size());
	for (idx_t key_idx = 0; key_idx < probe_col_ids.size(); key_idx++) {
		auto &column = const_cast<Vector &>(chunk.data[probe_col_ids[key_idx]]);
		column.ToUnifiedFormat(chunk.size(), formats[key_idx]);
	}

	SelectionVector bloom_matches(chunk.size());
	const auto bloom_match_count = bloom_filter->LookupHashes(hashes, bloom_matches, chunk.size());
	result_count = 0;
	for (idx_t match_idx = 0; match_idx < bloom_match_count; match_idx++) {
		const auto row = bloom_matches.get_index(match_idx);
		// TransferGraphManager only derives filters from COMPARE_EQUAL. SQL
		// equality never matches NULL, even when both sides contain NULL.
		if (!HasNullKey(formats, row)) {
			result.set_index(result_count++, row);
		}
	}
}

} // namespace duckdb
