#include "duckdb/optimizer/predicate_transfer/hash_filter.hpp"

#include "duckdb/common/exception.hpp"
#include "duckdb/common/types/vector.hpp"
#include "duckdb/common/vector_operations/vector_operations.hpp"

namespace duckdb {

namespace {

static Vector HashFilterComputeHashes(const DataChunk &chunk, const vector<idx_t> &column_ids) {
	D_ASSERT(!column_ids.empty());
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

static bool IsInlineLogicalType(const LogicalType &type) {
	switch (type.id()) {
	case LogicalTypeId::TINYINT:
	case LogicalTypeId::SMALLINT:
	case LogicalTypeId::INTEGER:
	case LogicalTypeId::BIGINT:
	case LogicalTypeId::UTINYINT:
	case LogicalTypeId::USMALLINT:
	case LogicalTypeId::UINTEGER:
	case LogicalTypeId::UBIGINT:
		return true;
	default:
		return false;
	}
}

static uint64_t ExtractInlineKey(const UnifiedVectorFormat &format, PhysicalType type, idx_t row) {
	const auto source_index = format.sel->get_index(row);
	switch (type) {
	case PhysicalType::INT8:
		return static_cast<uint64_t>(static_cast<uint8_t>(UnifiedVectorFormat::GetData<int8_t>(format)[source_index]));
	case PhysicalType::INT16:
		return static_cast<uint64_t>(
		    static_cast<uint16_t>(UnifiedVectorFormat::GetData<int16_t>(format)[source_index]));
	case PhysicalType::INT32:
		return static_cast<uint64_t>(
		    static_cast<uint32_t>(UnifiedVectorFormat::GetData<int32_t>(format)[source_index]));
	case PhysicalType::INT64:
		return static_cast<uint64_t>(UnifiedVectorFormat::GetData<int64_t>(format)[source_index]);
	case PhysicalType::UINT8:
		return static_cast<uint64_t>(UnifiedVectorFormat::GetData<uint8_t>(format)[source_index]);
	case PhysicalType::UINT16:
		return static_cast<uint64_t>(UnifiedVectorFormat::GetData<uint16_t>(format)[source_index]);
	case PhysicalType::UINT32:
		return static_cast<uint64_t>(UnifiedVectorFormat::GetData<uint32_t>(format)[source_index]);
	case PhysicalType::UINT64:
		return UnifiedVectorFormat::GetData<uint64_t>(format)[source_index];
	default:
		throw InternalException("HashFilter cannot inline physical type %s", TypeIdToString(type));
	}
}

static bool KeysEqual(const vector<Value> &left, const vector<Value> &right) {
	if (left.size() != right.size()) {
		return false;
	}
	for (idx_t key_idx = 0; key_idx < left.size(); key_idx++) {
		if (!Value::NotDistinctFrom(left[key_idx], right[key_idx])) {
			return false;
		}
	}
	return true;
}

} // namespace

HashFilter::HashFilter() {
	boxed_slots.assign(INITIAL_CAPACITY, BoxedSlot {0, EMPTY_KEY_INDEX});
	boxed_mask = INITIAL_CAPACITY - 1;
}

idx_t HashFilter::Capacity() const {
	return inline_storage ? inline_mask + 1 : boxed_mask + 1;
}

void HashFilter::DecideStorageMode(const DataChunk &chunk, const vector<idx_t> &build_col_ids) {
	D_ASSERT(key_arity == build_col_ids.size());
	if (build_col_ids.size() != 1 || !IsInlineLogicalType(chunk.data[build_col_ids[0]].GetType())) {
		return;
	}
	inline_storage = true;
	inline_type = chunk.data[build_col_ids[0]].GetType().InternalType();
	boxed_slots.clear();
	boxed_mask = 0;
	inline_slots.assign(INITIAL_CAPACITY, InlineSlot {0, 0});
	inline_occupancy.assign((INITIAL_CAPACITY + 63) / 64, 0);
	inline_mask = INITIAL_CAPACITY - 1;
}

void HashFilter::EnsureCapacity(idx_t additional) {
	while (count + additional > Capacity() - (Capacity() >> 2)) {
		const auto new_capacity = Capacity() * 2;
		if (new_capacity < Capacity()) {
			throw OutOfMemoryException("HashFilter capacity overflow");
		}
		if (inline_storage) {
			ResizeInline(new_capacity);
		} else {
			ResizeBoxed(new_capacity);
		}
	}
}

void HashFilter::ResizeBoxed(idx_t capacity) {
	D_ASSERT((capacity & (capacity - 1)) == 0);
	vector<BoxedSlot> resized(capacity, BoxedSlot {0, EMPTY_KEY_INDEX});
	const auto new_mask = capacity - 1;
	for (auto &slot : boxed_slots) {
		if (slot.key_index == EMPTY_KEY_INDEX) {
			continue;
		}
		auto target = slot.hash & new_mask;
		while (resized[target].key_index != EMPTY_KEY_INDEX) {
			target = (target + 1) & new_mask;
		}
		resized[target] = slot;
	}
	boxed_slots = std::move(resized);
	boxed_mask = new_mask;
}

void HashFilter::ResizeInline(idx_t capacity) {
	D_ASSERT((capacity & (capacity - 1)) == 0);
	vector<InlineSlot> resized(capacity, InlineSlot {0, 0});
	vector<uint64_t> resized_occupancy((capacity + 63) / 64, 0);
	const auto new_mask = capacity - 1;
	for (idx_t source = 0; source < inline_slots.size(); source++) {
		if (!InlineOccupied(source)) {
			continue;
		}
		auto target = inline_slots[source].hash & new_mask;
		while ((resized_occupancy[target >> 6] >> (target & 63)) & 1ULL) {
			target = (target + 1) & new_mask;
		}
		resized[target] = inline_slots[source];
		resized_occupancy[target >> 6] |= 1ULL << (target & 63);
	}
	inline_slots = std::move(resized);
	inline_occupancy = std::move(resized_occupancy);
	inline_mask = new_mask;
}

void HashFilter::InsertBoxed(vector<Value> key, hash_t hash) {
	EnsureCapacity(1);
	auto target = hash & boxed_mask;
	while (true) {
		auto &slot = boxed_slots[target];
		if (slot.key_index == EMPTY_KEY_INDEX) {
			stored_keys.push_back(std::move(key));
			slot = BoxedSlot {hash, stored_keys.size() - 1};
			count++;
			return;
		}
		if (slot.hash == hash && KeysEqual(stored_keys[slot.key_index], key)) {
			return;
		}
		target = (target + 1) & boxed_mask;
	}
}

void HashFilter::InsertInline(uint64_t key, hash_t hash) {
	EnsureCapacity(1);
	auto target = hash & inline_mask;
	while (true) {
		if (!InlineOccupied(target)) {
			inline_slots[target] = InlineSlot {hash, key};
			MarkInlineOccupied(target);
			count++;
			return;
		}
		const auto &slot = inline_slots[target];
		if (slot.hash == hash && slot.key == key) {
			return;
		}
		target = (target + 1) & inline_mask;
	}
}

void HashFilter::Build(const DataChunk &chunk, const vector<idx_t> &build_col_ids) {
	if (finalized) {
		throw InternalException("HashFilter::Build called after Finalize");
	}
	if (build_col_ids.empty()) {
		throw InternalException("HashFilter::Build requires at least one key column");
	}
	for (auto column_id : build_col_ids) {
		if (column_id >= chunk.ColumnCount()) {
			throw InternalException("HashFilter build column index is out of range");
		}
	}
	if (key_arity == 0) {
		key_arity = build_col_ids.size();
		DecideStorageMode(chunk, build_col_ids);
	} else if (key_arity != build_col_ids.size()) {
		throw InternalException("HashFilter build key arity changed");
	}

	const auto row_count = chunk.size();
	if (row_count == 0) {
		return;
	}
	auto hashes = HashFilterComputeHashes(chunk, build_col_ids);
	const auto hash_data = FlatVector::GetData<hash_t>(hashes);

	vector<UnifiedVectorFormat> formats(build_col_ids.size());
	for (idx_t key_idx = 0; key_idx < build_col_ids.size(); key_idx++) {
		auto &column = const_cast<Vector &>(chunk.data[build_col_ids[key_idx]]);
		column.ToUnifiedFormat(row_count, formats[key_idx]);
	}

	vector<Value> key;
	key.reserve(build_col_ids.size());
	for (idx_t row = 0; row < row_count; row++) {
		bool has_null = false;
		for (auto &format : formats) {
			if (!format.validity.RowIsValid(format.sel->get_index(row))) {
				has_null = true;
				break;
			}
		}
		if (has_null) {
			continue;
		}
		if (inline_storage) {
			InsertInline(ExtractInlineKey(formats[0], inline_type, row), hash_data[row]);
			continue;
		}
		key.clear();
		for (auto column_id : build_col_ids) {
			key.push_back(chunk.GetValue(column_id, row));
		}
		InsertBoxed(key, hash_data[row]);
	}
}

void HashFilter::Finalize() {
	finalized = true;
}

bool HashFilter::ContainsBoxed(const vector<Value> &key, hash_t hash) const {
	auto target = hash & boxed_mask;
	while (true) {
		const auto &slot = boxed_slots[target];
		if (slot.key_index == EMPTY_KEY_INDEX) {
			return false;
		}
		if (slot.hash == hash && KeysEqual(stored_keys[slot.key_index], key)) {
			return true;
		}
		target = (target + 1) & boxed_mask;
	}
}

bool HashFilter::ContainsInline(uint64_t key, hash_t hash) const {
	auto target = hash & inline_mask;
	while (true) {
		if (!InlineOccupied(target)) {
			return false;
		}
		const auto &slot = inline_slots[target];
		if (slot.hash == hash && slot.key == key) {
			return true;
		}
		target = (target + 1) & inline_mask;
	}
}

void HashFilter::Probe(const DataChunk &chunk, const vector<idx_t> &probe_col_ids, SelectionVector &result,
                       idx_t &result_count) const {
	result_count = 0;
	if (!finalized) {
		throw InternalException("HashFilter::Probe called before Finalize");
	}
	if (probe_col_ids.empty()) {
		throw InternalException("HashFilter::Probe requires at least one key column");
	}
	if (IsEmpty()) {
		return;
	}
	if (probe_col_ids.size() != key_arity) {
		throw InternalException("HashFilter probe key arity does not match build key arity");
	}
	for (auto column_id : probe_col_ids) {
		if (column_id >= chunk.ColumnCount()) {
			throw InternalException("HashFilter probe column index is out of range");
		}
	}

	const auto row_count = chunk.size();
	auto hashes = HashFilterComputeHashes(chunk, probe_col_ids);
	const auto hash_data = FlatVector::GetData<hash_t>(hashes);
	vector<UnifiedVectorFormat> formats(probe_col_ids.size());
	for (idx_t key_idx = 0; key_idx < probe_col_ids.size(); key_idx++) {
		auto &column = const_cast<Vector &>(chunk.data[probe_col_ids[key_idx]]);
		column.ToUnifiedFormat(row_count, formats[key_idx]);
	}

	vector<Value> key;
	key.reserve(probe_col_ids.size());
	for (idx_t row = 0; row < row_count; row++) {
		bool has_null = false;
		for (auto &format : formats) {
			if (!format.validity.RowIsValid(format.sel->get_index(row))) {
				has_null = true;
				break;
			}
		}
		if (has_null) {
			continue;
		}

		bool found;
		if (inline_storage) {
			found = ContainsInline(ExtractInlineKey(formats[0], inline_type, row), hash_data[row]);
		} else {
			key.clear();
			for (auto column_id : probe_col_ids) {
				key.push_back(chunk.GetValue(column_id, row));
			}
			found = ContainsBoxed(key, hash_data[row]);
		}
		if (found) {
			result.set_index(result_count++, row);
		}
	}
}

} // namespace duckdb
