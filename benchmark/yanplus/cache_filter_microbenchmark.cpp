// Isolated single-thread cache-boundary benchmark for Yan+ Bloom and inline Hash filters.
//
// The memory layouts and growth policies mirror the production implementations in
// src/planner/filter/bloom_filter.cpp and
// src/optimizer/predicate_transfer/hash_filter.cpp. A deterministic SplitMix-style
// hash replaces DuckDB's vector executor so the loop excludes SQL/vector overhead. The
// benchmark generates keys on demand so its reported working set is the filter itself.

#include <algorithm>
#include <cctype>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <limits>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

using Clock = std::chrono::steady_clock;

constexpr uint64_t BLOOM_MAX_SECTORS = 1ULL << 26;
constexpr uint64_t BLOOM_MIN_BITS_PER_KEY = 12;
constexpr uint64_t BLOOM_MIN_BITS = 512;
constexpr uint64_t BLOOM_ALIGNMENT_ALLOWANCE = 64;
constexpr uint64_t HASH_INITIAL_CAPACITY = 64;

volatile uint64_t result_sink = 0;

struct Options {
	std::string backend;
	uint64_t build_keys = 0;
	uint64_t probe_count = 20000000;
	double hit_rate = 0.5;
	uint64_t warmups = 1;
	uint64_t repetitions = 9;
	uint64_t seed = 15;
};

uint64_t ParseUnsigned(const std::string &text, const char *name) {
	size_t consumed = 0;
	uint64_t value;
	try {
		value = std::stoull(text, &consumed);
	} catch (const std::exception &) {
		throw std::runtime_error(std::string("invalid ") + name + ": " + text);
	}
	if (consumed != text.size()) {
		throw std::runtime_error(std::string("invalid ") + name + ": " + text);
	}
	return value;
}

double ParseDouble(const std::string &text, const char *name) {
	size_t consumed = 0;
	double value;
	try {
		value = std::stod(text, &consumed);
	} catch (const std::exception &) {
		throw std::runtime_error(std::string("invalid ") + name + ": " + text);
	}
	if (consumed != text.size() || !std::isfinite(value)) {
		throw std::runtime_error(std::string("invalid ") + name + ": " + text);
	}
	return value;
}

Options ParseOptions(int argc, char **argv) {
	Options options;
	for (int index = 1; index < argc; index++) {
		const std::string argument(argv[index]);
		auto value = [&](const char *name) -> std::string {
			if (index + 1 >= argc) {
				throw std::runtime_error(std::string("missing value for ") + name);
			}
			return argv[++index];
		};
		if (argument == "--backend") {
			options.backend = value("--backend");
		} else if (argument == "--build-keys") {
			options.build_keys = ParseUnsigned(value("--build-keys"), "--build-keys");
		} else if (argument == "--probe-count") {
			options.probe_count = ParseUnsigned(value("--probe-count"), "--probe-count");
		} else if (argument == "--hit-rate") {
			options.hit_rate = ParseDouble(value("--hit-rate"), "--hit-rate");
		} else if (argument == "--warmups") {
			options.warmups = ParseUnsigned(value("--warmups"), "--warmups");
		} else if (argument == "--repetitions") {
			options.repetitions = ParseUnsigned(value("--repetitions"), "--repetitions");
		} else if (argument == "--seed") {
			options.seed = ParseUnsigned(value("--seed"), "--seed");
		} else if (argument == "--help" || argument == "-h") {
			std::cout
			    << "Usage: cache_filter_microbenchmark --backend bloom|hash --build-keys N\n"
			    << "       [--probe-count N] [--hit-rate F] [--warmups N]\n"
			    << "       [--repetitions N] [--seed N]\n";
			std::exit(0);
		} else {
			throw std::runtime_error("unknown argument: " + argument);
		}
	}
	std::transform(options.backend.begin(), options.backend.end(), options.backend.begin(),
	               [](unsigned char value) { return static_cast<char>(std::tolower(value)); });
	if (options.backend != "bloom" && options.backend != "hash") {
		throw std::runtime_error("--backend must be bloom or hash");
	}
	if (options.build_keys == 0) {
		throw std::runtime_error("--build-keys must be positive");
	}
	if (options.probe_count == 0) {
		throw std::runtime_error("--probe-count must be positive");
	}
	if (options.repetitions == 0) {
		throw std::runtime_error("--repetitions must be positive");
	}
	if (options.hit_rate < 0 || options.hit_rate > 1) {
		throw std::runtime_error("--hit-rate must be between 0 and 1");
	}
	return options;
}

uint64_t NextPowerOfTwo(uint64_t value) {
	if (value <= 1) {
		return 1;
	}
	if (value > (1ULL << 63)) {
		throw std::runtime_error("power-of-two overflow");
	}
	value--;
	value |= value >> 1;
	value |= value >> 2;
	value |= value >> 4;
	value |= value >> 8;
	value |= value >> 16;
	value |= value >> 32;
	return value + 1;
}

uint64_t Mix(uint64_t value) {
	value += 0x9E3779B97F4A7C15ULL;
	value = (value ^ (value >> 30)) * 0xBF58476D1CE4E5B9ULL;
	value = (value ^ (value >> 27)) * 0x94D049BB133111EBULL;
	return value ^ (value >> 31);
}

uint64_t KeyForIndex(uint64_t index) {
	// Multiplication by an odd number is one-to-one modulo 2^64.
	return index * 0xD6E8FEB86659FD93ULL + 0xA0761D6478BD642FULL;
}

uint64_t ScaleToRange(uint64_t random_value, uint64_t range) {
#if defined(__SIZEOF_INT128__)
	return static_cast<uint64_t>((static_cast<unsigned __int128>(random_value) * range) >> 64);
#else
	return random_value % range;
#endif
}

uint64_t BloomMask(uint64_t hash) {
	uint64_t mask = 0;
	for (uint64_t byte_index = 4; byte_index < 8; byte_index++) {
		const uint64_t bit_position = (hash >> (byte_index * 8)) & 63ULL;
		mask |= 1ULL << bit_position;
	}
	return mask;
}

class BloomFilterBenchmark {
public:
	explicit BloomFilterBenchmark(uint64_t number_of_rows) {
		if (number_of_rows > std::numeric_limits<uint64_t>::max() / BLOOM_MIN_BITS_PER_KEY) {
			throw std::runtime_error("Bloom row count overflow");
		}
		const auto minimum_bits =
		    std::max<uint64_t>(BLOOM_MIN_BITS, number_of_rows * BLOOM_MIN_BITS_PER_KEY);
		num_sectors = std::min<uint64_t>(NextPowerOfTwo(minimum_bits) >> 6, BLOOM_MAX_SECTORS);
		bitmask = num_sectors - 1;
		// Eight spare words reproduce the production allocator's 64-byte alignment allowance.
		storage.assign(num_sectors + 8, 0);
		const auto address = reinterpret_cast<uintptr_t>(storage.data());
		const auto aligned = (address + 63ULL) & ~uintptr_t(63ULL);
		words = reinterpret_cast<uint64_t *>(aligned);
	}

	void Insert(uint64_t key) {
		const auto hash = Mix(key);
		const auto offset = hash & bitmask;
#if defined(__clang__) || defined(__GNUC__)
		__atomic_fetch_or(&words[offset], BloomMask(hash), __ATOMIC_RELAXED);
#else
		words[offset] |= BloomMask(hash);
#endif
	}

	bool Contains(uint64_t key) const {
		const auto hash = Mix(key);
		const auto mask = BloomMask(hash);
		return (words[hash & bitmask] & mask) == mask;
	}

	uint64_t MemoryBytes() const {
		return BLOOM_ALIGNMENT_ALLOWANCE + num_sectors * sizeof(uint64_t);
	}
	uint64_t PeakMemoryBytes() const {
		return MemoryBytes();
	}

private:
	uint64_t num_sectors = 0;
	uint64_t bitmask = 0;
	std::vector<uint64_t> storage;
	uint64_t *words = nullptr;
};

class HashFilterBenchmark {
public:
	struct InlineSlot {
		uint64_t hash;
		uint64_t key;
	};

	HashFilterBenchmark() {
		static_assert(sizeof(InlineSlot) == 16, "unexpected inline Hash slot size");
		// Production constructs a 64-slot boxed table, then clear() retains that
		// allocation when the first single-integer chunk selects inline storage.
		retained_boxed_slots.assign(HASH_INITIAL_CAPACITY, InlineSlot {0, 0});
		retained_boxed_slots.clear();
		slots.assign(HASH_INITIAL_CAPACITY, InlineSlot {0, 0});
		occupancy.assign((HASH_INITIAL_CAPACITY + 63) / 64, 0);
		mask = HASH_INITIAL_CAPACITY - 1;
		peak_memory_bytes = MemoryBytes();
	}

	void Insert(uint64_t key) {
		EnsureCapacity(1);
		const auto hash = Mix(key);
		auto target = hash & mask;
		while (true) {
			if (!Occupied(target)) {
				slots[target] = InlineSlot {hash, key};
				occupancy[target >> 6] |= 1ULL << (target & 63);
				count++;
				return;
			}
			const auto &slot = slots[target];
			if (slot.hash == hash && slot.key == key) {
				return;
			}
			target = (target + 1) & mask;
		}
	}

	bool Contains(uint64_t key) const {
		const auto hash = Mix(key);
		auto target = hash & mask;
		while (true) {
			if (!Occupied(target)) {
				return false;
			}
			const auto &slot = slots[target];
			if (slot.hash == hash && slot.key == key) {
				return true;
			}
			target = (target + 1) & mask;
		}
	}

	uint64_t MemoryBytes() const {
		return retained_boxed_slots.capacity() * sizeof(InlineSlot) +
		       slots.capacity() * sizeof(InlineSlot) + occupancy.capacity() * sizeof(uint64_t);
	}
	uint64_t PeakMemoryBytes() const {
		return peak_memory_bytes;
	}

private:
	bool Occupied(uint64_t index) const {
		return (occupancy[index >> 6] >> (index & 63)) & 1ULL;
	}

	void EnsureCapacity(uint64_t additional) {
		while (count + additional > slots.size() - (slots.size() >> 2)) {
			Resize(slots.size() * 2);
		}
	}

	void Resize(uint64_t capacity) {
		std::vector<InlineSlot> resized(capacity, InlineSlot {0, 0});
		std::vector<uint64_t> resized_occupancy((capacity + 63) / 64, 0);
		peak_memory_bytes = std::max<uint64_t>(
		    peak_memory_bytes,
		    MemoryBytes() + resized.capacity() * sizeof(InlineSlot) +
		        resized_occupancy.capacity() * sizeof(uint64_t));
		const auto resized_mask = capacity - 1;
		for (uint64_t source = 0; source < slots.size(); source++) {
			if (!Occupied(source)) {
				continue;
			}
			auto target = slots[source].hash & resized_mask;
			while ((resized_occupancy[target >> 6] >> (target & 63)) & 1ULL) {
				target = (target + 1) & resized_mask;
			}
			resized[target] = slots[source];
			resized_occupancy[target >> 6] |= 1ULL << (target & 63);
		}
		slots = std::move(resized);
		occupancy = std::move(resized_occupancy);
		mask = resized_mask;
	}

	std::vector<InlineSlot> retained_boxed_slots;
	std::vector<InlineSlot> slots;
	std::vector<uint64_t> occupancy;
	uint64_t mask = 0;
	uint64_t count = 0;
	uint64_t peak_memory_bytes = 0;
};

struct Measurements {
	std::vector<double> initialization_seconds;
	std::vector<double> insertion_seconds;
	std::vector<double> probe_seconds;
	uint64_t filter_bytes = 0;
	uint64_t peak_build_bytes = 0;
	double generated_hit_rate = 0;
	double observed_match_rate = 0;
	double false_positive_rate = 0;
};

template <class FILTER, class FACTORY>
Measurements RunTyped(const Options &options, FACTORY create_filter) {
	Measurements result;
	const auto total_iterations = options.warmups + options.repetitions;
	uint64_t final_matches = 0;
	uint64_t final_requested_hits = 0;
	for (uint64_t iteration = 0; iteration < total_iterations; iteration++) {
		const auto initialization_start = Clock::now();
		auto filter = create_filter();
		const auto initialization_end = Clock::now();

		const auto insertion_start = initialization_end;
		for (uint64_t key_index = 0; key_index < options.build_keys; key_index++) {
			filter->Insert(KeyForIndex(key_index));
		}
		const auto insertion_end = Clock::now();

		uint64_t matches = 0;
		uint64_t requested_hits = 0;
		const auto hit_threshold = static_cast<long double>(options.hit_rate) *
		                           static_cast<long double>(std::numeric_limits<uint64_t>::max());
		const auto probe_start = insertion_end;
		for (uint64_t probe_index = 0; probe_index < options.probe_count; probe_index++) {
			const auto random_value = Mix(probe_index + options.seed + iteration * 0x9E3779B9ULL);
			const bool should_hit = static_cast<long double>(random_value) <= hit_threshold;
			requested_hits += should_hit;
			uint64_t source_index;
			if (should_hit) {
				source_index = ScaleToRange(Mix(random_value), options.build_keys);
			} else {
				source_index = options.build_keys + ScaleToRange(Mix(random_value), options.build_keys);
			}
			matches += filter->Contains(KeyForIndex(source_index));
		}
		const auto probe_end = Clock::now();
		result_sink ^= matches;
		final_matches = matches;
		final_requested_hits = requested_hits;
		result.filter_bytes = filter->MemoryBytes();
		result.peak_build_bytes = filter->PeakMemoryBytes();

		if (iteration >= options.warmups) {
			result.initialization_seconds.push_back(
			    std::chrono::duration<double>(initialization_end - initialization_start).count());
			result.insertion_seconds.push_back(
			    std::chrono::duration<double>(insertion_end - insertion_start).count());
			result.probe_seconds.push_back(
			    std::chrono::duration<double>(probe_end - probe_start).count());
		}
	}
	result.generated_hit_rate = static_cast<double>(final_requested_hits) / options.probe_count;
	result.observed_match_rate = static_cast<double>(final_matches) / options.probe_count;
	const auto requested_misses = options.probe_count - final_requested_hits;
	result.false_positive_rate = requested_misses == 0
	                                 ? 0
	                                 : static_cast<double>(final_matches - final_requested_hits) /
	                                       requested_misses;
	return result;
}

double Median(std::vector<double> values) {
	std::sort(values.begin(), values.end());
	const auto middle = values.size() / 2;
	if (values.size() % 2) {
		return values[middle];
	}
	return (values[middle - 1] + values[middle]) / 2;
}

double Percentile95(std::vector<double> values) {
	std::sort(values.begin(), values.end());
	const auto rank = static_cast<size_t>(std::ceil(values.size() * 0.95));
	return values[std::max<size_t>(1, rank) - 1];
}

std::string Samples(const std::vector<double> &values) {
	std::ostringstream result;
	result << std::fixed << std::setprecision(9);
	for (size_t index = 0; index < values.size(); index++) {
		if (index) {
			result << ';';
		}
		result << values[index];
	}
	return result.str();
}

void PrintResult(const Options &options, const Measurements &measurements) {
	const auto init_median = Median(measurements.initialization_seconds);
	const auto insertion_median = Median(measurements.insertion_seconds);
	const auto probe_median = Median(measurements.probe_seconds);
	std::vector<double> total_build_samples;
	for (size_t index = 0; index < measurements.insertion_seconds.size(); index++) {
		total_build_samples.push_back(measurements.initialization_seconds[index] +
		                              measurements.insertion_seconds[index]);
	}
	const auto total_build_median = Median(total_build_samples);
	std::cout
	    << "backend,build_keys,probe_count,requested_hit_rate,repetitions,filter_bytes,peak_build_bytes,"
	       "initialization_median_seconds,insertion_median_seconds,build_median_seconds,"
	       "build_p95_seconds,build_ns_per_key,probe_median_seconds,probe_p95_seconds,"
	       "probe_ns_per_key,generated_hit_rate,observed_match_rate,false_positive_rate,"
	       "initialization_samples_seconds,"
	       "insertion_samples_seconds,probe_samples_seconds\n";
	std::cout << std::fixed << std::setprecision(9) << options.backend << ',' << options.build_keys << ','
	          << options.probe_count << ',' << options.hit_rate << ',' << options.repetitions << ','
	          << measurements.filter_bytes << ',' << measurements.peak_build_bytes << ',' << init_median << ','
	          << insertion_median << ','
	          << total_build_median << ',';
	std::cout << Percentile95(total_build_samples) << ','
	          << total_build_median * 1e9 / options.build_keys << ',' << probe_median << ','
	          << Percentile95(measurements.probe_seconds) << ','
	          << probe_median * 1e9 / options.probe_count << ',' << measurements.generated_hit_rate << ','
	          << measurements.observed_match_rate << ',' << measurements.false_positive_rate << ','
	          << Samples(measurements.initialization_seconds) << ','
	          << Samples(measurements.insertion_seconds) << ',' << Samples(measurements.probe_seconds) << '\n';
}

} // namespace

int main(int argc, char **argv) {
	try {
		const auto options = ParseOptions(argc, argv);
		Measurements measurements;
		if (options.backend == "bloom") {
			measurements = RunTyped<BloomFilterBenchmark>(
			    options, [&]() { return std::make_unique<BloomFilterBenchmark>(options.build_keys); });
		} else {
			measurements =
			    RunTyped<HashFilterBenchmark>(options, [&]() { return std::make_unique<HashFilterBenchmark>(); });
		}
		PrintResult(options, measurements);
		return result_sink == std::numeric_limits<uint64_t>::max() ? 1 : 0;
	} catch (const std::exception &error) {
		std::cerr << "Error: " << error.what() << '\n';
		return 1;
	}
}
