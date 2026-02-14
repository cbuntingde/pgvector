-- Test RRF hybrid search combining vector and full-text search

-- Create test table with vector and text search columns
CREATE TABLE items (
    id SERIAL PRIMARY KEY,
    embedding vector(3),
    content text,
    textsearch tsvector
);

-- Insert test data
INSERT INTO items (embedding, content, textsearch) VALUES
    ('[1,2,3]', 'hello world', to_tsvector('hello world')),
    ('[1,1,1]', 'hello postgres', to_tsvector('hello postgres')),
    ('[2,2,2]', 'world postgres', to_tsvector('world postgres')),
    ('[3,3,3]', 'postgres ai machine learning', to_tsvector('postgres ai machine learning')),
    ('[4,4,4]', 'artificial intelligence database', to_tsvector('artificial intelligence database')),
    ('[5,5,5]', 'sql query optimization', to_tsvector('sql query optimization'));

-- Create HNSW index for vector search
CREATE INDEX ON items USING hnsw (embedding vector_cosine_ops);

-- Test 1: Pure vector search
SELECT id, embedding <=> '[1,2,3]' AS distance
FROM items
ORDER BY distance
LIMIT 3;

-- Test 2: Pure text search
SELECT id, ts_rank_cd(textsearch, plainto_tsquery('hello postgres')) AS rank
FROM items
WHERE textsearch @@ plainto_tsquery('hello postgres')
ORDER BY rank DESC;

-- Test 3: RRF hybrid search combining vector and text results
-- This is the primary use case for rrf_score
WITH vector_results AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY embedding <=> '[1,2,3]') AS rank
    FROM items
),
text_results AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY ts_rank_cd(textsearch, plainto_tsquery('hello postgres')) DESC) AS rank
    FROM items
    WHERE textsearch @@ plainto_tsquery('hello postgres')
),
combined AS (
    SELECT id, rank FROM vector_results
    UNION ALL
    SELECT id, rank FROM text_results
)
SELECT 
    id,
    SUM(rrf_score(rank)) AS rrf_score,
    COUNT(*) AS result_count
FROM combined
GROUP BY id
ORDER BY rrf_score DESC;

-- Test 4: RRF with explicit k parameter
WITH vector_results AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY embedding <=> '[1,2,3]') AS rank
    FROM items
),
text_results AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY ts_rank_cd(textsearch, plainto_tsquery('postgres')) DESC) AS rank
    FROM items
    WHERE textsearch @@ plainto_tsquery('postgres')
),
combined AS (
    SELECT id, rank FROM vector_results
    UNION ALL
    SELECT id, rank FROM text_results
)
SELECT 
    id,
    SUM(rrf_score(rank, 60)) AS rrf_score_60,
    SUM(rrf_score(rank, 100)) AS rrf_score_100
FROM combined
GROUP BY id
ORDER BY rrf_score_60 DESC;

-- Test 5: Verify different k values produce different rankings
WITH results AS (
    SELECT 1 AS id, 1 AS rank
    UNION ALL
    SELECT 2 AS id, 2 AS rank
    UNION ALL
    SELECT 1 AS id, 1 AS rank
)
SELECT 
    id,
    SUM(rrf_score(rank, 10)) AS k10,
    SUM(rrf_score(rank, 60)) AS k60,
    SUM(rrf_score(rank, 1000)) AS k1000
FROM results
GROUP BY id
ORDER BY k10 DESC, k60 DESC;

-- Test 6: RRF with weighted combination
-- Weight vector results higher
WITH vector_results AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY embedding <=> '[1,2,3]') AS rank
    FROM items
),
text_results AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY ts_rank_cd(textsearch, plainto_tsquery('ai')) DESC) AS rank
    FROM items
    WHERE textsearch @@ plainto_tsquery('ai')
),
combined AS (
    SELECT id, rank, 'vector' AS source FROM vector_results
    UNION ALL
    SELECT id, rank, 'text' AS source FROM text_results
)
SELECT 
    id,
    source,
    SUM(
        rrf_score(rank) * 
        CASE source 
            WHEN 'vector' THEN 0.7 
            WHEN 'text' THEN 0.3 
        END
    ) AS weighted_score
FROM combined
GROUP BY id, source
ORDER BY weighted_score DESC;

-- Cleanup
DROP TABLE items;
