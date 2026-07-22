#include "duckdb/execution/operator/filter/physical_use_bf.hpp"

#include "duckdb/parallel/meta_pipeline.hpp"
#include "duckdb/parallel/thread_context.hpp"

namespace duckdb {
PhysicalUseBF::PhysicalUseBF(PhysicalPlan &physical_plan, vector<LogicalType> types,
                             const shared_ptr<FilterPlan> &filter_plan, shared_ptr<SemiJoinFilterUsage> filter,
                             PhysicalCreateBF *related_create_bfs, idx_t estimated_cardinality)
    : CachingPhysicalOperator(physical_plan, PhysicalOperatorType::USE_BF, std::move(types), estimated_cardinality),
      filter_plan(filter_plan), related_creator(related_create_bfs), filter_to_use(std::move(filter)) {
}

class UseBFState : public CachingOperatorState {
public:
	static constexpr int64_t NUM_CHUNK_FOR_CHECK = 32;
	static constexpr double SELECTIVITY_THRESHOLD = 0.9;

public:
	explicit UseBFState(bool valid_bf) : sel_vector(STANDARD_VECTOR_SIZE), use_bf(valid_bf) {
	}

	SelectionVector sel_vector;

	bool use_bf;
	bool is_checked = false;
	int64_t num_chunk = 0;
	uint64_t num_received = 0;
	uint64_t num_sent = 0;

public:
	void CheckBFSelectivity(uint64_t num_in, uint64_t num_out) {
		num_received += num_in;
		num_sent += num_out;
		num_chunk++;

		if (num_chunk > NUM_CHUNK_FOR_CHECK) {
			is_checked = true;

			double selectivity = static_cast<double>(num_sent) / static_cast<double>(num_received);
			if (selectivity > SELECTIVITY_THRESHOLD && selectivity < 1) {
				use_bf = false;
			}
		}
	}

	void Finalize(const PhysicalOperator &op, ExecutionContext &context) override {
		context.thread.profiler.Flush(op);
	}
};

unique_ptr<OperatorState> PhysicalUseBF::GetOperatorState(ExecutionContext &context) const {
	return make_uniq<UseBFState>(filter_to_use->IsValid());
}

InsertionOrderPreservingMap<string> PhysicalUseBF::ParamsToString() const {
	InsertionOrderPreservingMap<string> result;
	result["BF Creators"] = "0x" + std::to_string(reinterpret_cast<size_t>(related_creator)) + "\n";
	result["Semi-Join Filter Type"] = filter_to_use->GetTypeName();
	return result;
}

void PhysicalUseBF::BuildPipelines(Pipeline &current, MetaPipeline &meta_pipeline) {
	op_state.reset();

	auto &state = meta_pipeline.GetState();
	state.AddPipelineOperator(current, *this);
	related_creator->BuildPipelinesFromRelated(current, meta_pipeline);
	children[0].get().BuildPipelines(current, meta_pipeline);
}

OperatorResultType PhysicalUseBF::ExecuteInternal(ExecutionContext &context, DataChunk &input, DataChunk &chunk,
                                                  GlobalOperatorState &gstate, OperatorState &state_p) const {
	auto &state = state_p.Cast<UseBFState>();

	// This operator has no BloomFilter to use
	if (!state.use_bf) {
		chunk.Reference(input);
		return OperatorResultType::NEED_MORE_INPUT;
	}

	idx_t result_count = 0;
	auto &sel = state.sel_vector;
	filter_to_use->Probe(input, sel, result_count);

	// Fill the output using the selection produced by either backend.
	if (result_count == input.size()) {
		// nothing was filtered: skip adding any selection vectors
		chunk.Reference(input);
	} else {
		chunk.Slice(input, sel, result_count);
	}

	// 3. Update statistics
	if (!state.is_checked) {
		state.CheckBFSelectivity(input.size(), result_count);
	}

	return OperatorResultType::NEED_MORE_INPUT;
}
} // namespace duckdb
