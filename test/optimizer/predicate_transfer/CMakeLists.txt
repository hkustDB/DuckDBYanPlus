add_library_unity(test_optimizer_predicate_transfer OBJECT hash_filter_test.cpp semi_join_filter_test.cpp)

set(ALL_OBJECT_FILES
    ${ALL_OBJECT_FILES} $<TARGET_OBJECTS:test_optimizer_predicate_transfer>
    PARENT_SCOPE)
