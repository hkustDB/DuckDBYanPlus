//===----------------------------------------------------------------------===//
//                         DuckDB
//
// duckdb/optimizer/predicate_transfer/semi_join_filter.hpp
//
//===----------------------------------------------------------------------===//

#pragma once

#include "duckdb/common/shared_ptr.hpp"
#include "duckdb/common/types/data_chunk.hpp"
#include "duckdb/common/types/selection_vector.hpp"
#include "duckdb/common/unique_ptr.hpp"

namespace duckdb {

class BloomFilter;
class HashFilter;

//! Runtime backend for Yan+ semi-join filters. BLOOM is deliberately the
//! default so existing Yan+ behavior remains unchanged unless the experiment
//! explicitly selects HASH.
enum class YanplusSemiJoinFilterType : uint8_t { BLOOM, HASH };

class SemiJoinFilter {
public:
	explicit SemiJoinFilter(YanplusSemiJoinFilterType type);
	~SemiJoinFilter();

	void Initialize(ClientContext &context, idx_t expected_rows);
	void Insert(const DataChunk &chunk, const vector<idx_t> &build_col_ids);
	void Finalize();
	void Probe(const DataChunk &chunk, const vector<idx_t> &probe_col_ids, SelectionVector &result,
	           idx_t &result_count) const;

	YanplusSemiJoinFilterType GetType() const {
		return type;
	}
	const char *GetTypeName() const;
	bool IsFinalized() const {
		return finalized;
	}

private:
	YanplusSemiJoinFilterType type;
	unique_ptr<BloomFilter> bloom_filter;
	unique_ptr<HashFilter> hash_filter;
	bool initialized = false;
	bool finalized = false;
};

//! Binds one shared filter to the probe-side column positions of a USE_BF
//! operator. Multiple probe operators may safely share the same usage/filter.
class SemiJoinFilterUsage {
public:
	SemiJoinFilterUsage(shared_ptr<SemiJoinFilter> filter, vector<idx_t> probe_col_ids)
	    : filter(std::move(filter)), probe_col_ids(std::move(probe_col_ids)) {
	}

	bool IsValid() const {
		return filter->IsFinalized();
	}
	void Probe(const DataChunk &chunk, SelectionVector &result, idx_t &result_count) const {
		filter->Probe(chunk, probe_col_ids, result, result_count);
	}
	YanplusSemiJoinFilterType GetType() const {
		return filter->GetType();
	}
	const char *GetTypeName() const {
		return filter->GetTypeName();
	}

private:
	shared_ptr<SemiJoinFilter> filter;
	vector<idx_t> probe_col_ids;
};

} // namespace duckdb
