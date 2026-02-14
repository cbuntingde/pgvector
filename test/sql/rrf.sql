-- Test RRF (Reciprocal Rank Fusion) functions

-- Basic rrf_score function tests

-- Test with default k=60
SELECT round(rrf_score(1)::numeric, 6);
SELECT round(rrf_score(10)::numeric, 6);
SELECT round(rrf_score(100)::numeric, 6);
SELECT round(rrf_score(1000)::numeric, 6);

-- Test with custom k value
SELECT round(rrf_score(1, 60)::numeric, 6);
SELECT round(rrf_score(1, 10)::numeric, 6);
SELECT round(rrf_score(1, 100)::numeric, 6);

-- Test with k=0 (edge case - division by near-zero)
SELECT rrf_score(1, 0);

-- Test with negative rank (should handle gracefully)
SELECT rrf_score(-1);

-- Test with rank=0
SELECT round(rrf_score(0)::numeric, 6);

-- Test combining ranks with SUM for RRF
SELECT id, SUM(rrf_score(rank)) AS rrf_score
FROM (VALUES (1, 1), (2, 2), (1, 3)) AS t(id, rank)
GROUP BY id
ORDER BY rrf_score DESC;

-- Test RRF with duplicate ids across different result sets
SELECT id, SUM(rrf_score(rank)) AS rrf_score
FROM (
    SELECT 1 AS id, 1 AS rank
    UNION ALL
    SELECT 1 AS id, 2 AS rank
    UNION ALL
    SELECT 2 AS id, 1 AS rank
) combined
GROUP BY id
ORDER BY rrf_score DESC;

-- Test with large ranks
SELECT round(rrf_score(10000)::numeric, 8);
SELECT round(rrf_score(100000)::numeric, 10);
