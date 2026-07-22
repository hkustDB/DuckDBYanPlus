//===----------------------------------------------------------------------===//
//                         DuckDB
//
// duckdb/optimizer/predicate_transfer/hash_filter.hpp
//
//===----------------------------------------------------------------------===//

#pragma once

#include "duckdb/common/limits.hpp"
#include "duckdb/common/types/data_chunk.hpp"
#include "duckdb/common/types/selection_vector.hpp"
#include "duckdb/common/types/value.hpp"

namespace duckdb {

//! Exact set-membership filter used as the Hash alternative to Yan+'s Bloom
//! filter. It uses inline storage for a single integer key and collision-safe
//! boxed Value tuples for all other supported key shapes.
class HashFilter {
public:
	HashFilter();

	void Build(const DataChunk &chunk, const vector<idx_t> &build_col_ids);
	void Finalize();
	void Probe(const DataChunk &chunk, const vector<idx_t> &probe_col_ids, SelectionVector &result,
	           idx_t &result_count) const;

	bool IsFinalized() const {
		return finalized;
	}
	bool IsEmpty() const {
		return count == 0;
	}
	idx_t Count() const {
		return count;
	}
	idx_t Capacity() const;
	idx_t KeyArity() const {
		return key_arity;
	}
	bool IsInline() const {
		return inline_storage;
	}

private:
	struct BoxedSlot {
		hash_t hash;
		idx_t key_index;
	};

	struct InlineSlot {
		hash_t hash;
		uint64_t key;
	};

	static constexpr idx_t INITIAL_CAPACITY = 64;
	static constexpr idx_t EMPTY_KEY_INDEX = NumericLimits<idx_t>::Maximum();

	void DecideStorageMode(const DataChunk &chunk, const vector<idx_t> &build_col_ids);
	void EnsureCapacity(idx_t additional);
	void ResizeBoxed(idx_t capacity);
	void ResizeInline(idx_t capacity);
	void InsertBoxed(vector<Value> key, hash_t hash);
	void InsertInline(uint64_t key, hash_t hash);
	bool ContainsBoxed(const vector<Value> &key, hash_t hash) const;
	bool ContainsInline(uint64_t key, hash_t hash) const;

	bool InlineOccupied(idx_t index) const {
		return (inline_occupancy[index >> 6] >> (index & 63)) & 1ULL;
	}
	void MarkInlineOccupied(idx_t index) {
		inline_occupancy[index >> 6] |= 1ULL << (index & 63);
	}

	vector<BoxedSlot> boxed_slots;
	vector<vector<Value>> stored_keys;
	idx_t boxed_mask = 0;

	vector<InlineSlot> inline_slots;
	vector<uint64_t> inline_occupancy;
	idx_t inline_mask = 0;
	PhysicalType inline_type = PhysicalType::INVALID;

	bool inline_storage = false;
	idx_t key_arity = 0;
	idx_t count = 0;
	bool finalized = false;
};

} // namespace duckdb
