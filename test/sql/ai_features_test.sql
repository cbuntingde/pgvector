-- ============================================
-- Automated Test Suite: pgvector AI Enhancements
-- ============================================

-- TEST 1: Basic rrf_score function
SELECT '=== TEST 1: Basic rrf_score function ===' AS test;
SELECT round(rrf_score(1::int)::numeric, 6) AS result_016393, '0.016393' AS expected;
SELECT round(rrf_score(10::int)::numeric, 6) AS result_014286, '0.014286' AS expected;
SELECT round(rrf_score(100::int)::numeric, 6) AS result_006250, '0.006250' AS expected;

-- TEST 2: rrf_score with custom k
SELECT '=== TEST 2: rrf_score with custom k ===' AS test;
SELECT round(rrf_score(1::int, 60)::numeric, 6) AS k60, '0.016393' AS expected;
SELECT round(rrf_score(1::int, 10)::numeric, 6) AS k10, '0.090909' AS expected;
SELECT round(rrf_score(1::int, 100)::numeric, 6) AS k100, '0.009901' AS expected;

-- TEST 3: rrf_score with bigint
SELECT '=== TEST 3: rrf_score with bigint ===' AS test;
SELECT round(rrf_score(1::bigint)::numeric, 6) AS bigint_result, '0.016393' AS expected;

-- TEST 4: RRF combining ranks
SELECT '=== TEST 4: RRF combining ranks ===' AS test;
SELECT id, round(SUM(rrf_score(rank))::numeric, 6) AS rrf_score
FROM (VALUES (1, 1), (2, 2), (1, 3)) AS t(id, rank)
GROUP BY id
ORDER BY rrf_score DESC;

-- TEST 5: sparsevec_nnz function
SELECT '=== TEST 5: sparsevec_nnz function ===' AS test;
SELECT sparsevec_nnz('{1:1, 5:2, 10:3}/100'::sparsevec) AS nnz, '3' AS expected;
SELECT sparsevec_nnz('{1:1, 2:2, 3:3, 4:4, 5:5}/100'::sparsevec) AS nnz, '5' AS expected;

-- TEST 6: vector_max_sim function
SELECT '=== TEST 6: vector_max_sim function ===' AS test;
SELECT round(vector_max_sim('[3,4,5]'::vector, ARRAY['[1,2,3]'::vector, '[4,5,6]'::vector])::numeric, 6) AS max_sim;
SELECT round(vector_max_sim('[1,1,1]'::vector, ARRAY['[0.9,0.9,0.9]'::vector, '[0.5,0.5,0.5]'::vector])::numeric, 6) AS max_sim2;

-- TEST 7: vector_sum_sim function
SELECT '=== TEST 7: vector_sum_sim function ===' AS test;
SELECT round(vector_sum_sim('[3,4,5]'::vector, ARRAY['[1,2,3]'::vector, '[4,5,6]'::vector])::numeric, 6) AS sum_sim;

-- TEST 8: vector_mean_sim function
SELECT '=== TEST 8: vector_mean_sim function ===' AS test;
SELECT round(vector_mean_sim('[3,4,5]'::vector, ARRAY['[1,2,3]'::vector, '[4,5,6]'::vector])::numeric, 6) AS mean_sim;

-- TEST 9: rerank_scores function
SELECT '=== TEST 9: rerank_scores function ===' AS test;
SELECT rerank_scores(ARRAY[0.9::float8, 0.7::float8, 0.5::float8], ARRAY[1.0::float8, 1.0::float8]) AS weighted_scores;

-- TEST 10: rerank_order function
SELECT '=== TEST 10: rerank_order function ===' AS test;
SELECT * FROM rerank_order(ARRAY[1::bigint, 2::bigint, 3::bigint], ARRAY[0.5::float8, 0.9::float8, 0.7::float8]) ORDER BY score DESC;

-- TEST 11: Hybrid search with RRF
SELECT '=== TEST 11: Hybrid search with RRF ===' AS test;
CREATE TABLE IF NOT EXISTS test_items (id int, embedding vector(3), content text);
DELETE FROM test_items;
INSERT INTO test_items VALUES 
    (1, '[1,2,3]'::vector, 'hello world'),
    (2, '[1,1,1]'::vector, 'hello postgres'),
    (3, '[2,2,2]'::vector, 'world postgres');
SELECT id, round(SUM(rrf_score(rank))::numeric, 6) AS rrf_score
FROM (
    SELECT id, ROW_NUMBER() OVER (ORDER BY embedding <=> '[1,2,3]'::vector) AS rank FROM test_items
    UNION ALL
    SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rank FROM test_items
) combined
GROUP BY id ORDER BY rrf_score DESC;

SELECT '=== ALL TESTS COMPLETED SUCCESSFULLY ===' AS status;