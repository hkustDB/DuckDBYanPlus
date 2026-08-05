-- Locally simulated DuckDB Yannakakis-style two-pass reduction.
-- The grouped MPP CTE is treated as one relation in the acyclic reduction.
CREATE OR REPLACE TEMP VIEW ya_bi9_mpp_up AS
SELECT RootPostId, count(*) AS MessageCount
FROM Message
WHERE Message.creationDate BETWEEN :startDate AND :endDate
GROUP BY RootPostId;
CREATE OR REPLACE TEMP VIEW ya_bi9_post_up AS
SELECT Post.* FROM Post_View AS Post
WHERE Post.creationDate BETWEEN :startDate AND :endDate
  AND EXISTS (SELECT 1 FROM ya_bi9_mpp_up AS MPP WHERE Post.id = MPP.RootPostId);
CREATE OR REPLACE TEMP VIEW ya_bi9_person_down AS
SELECT Person.* FROM Person
WHERE EXISTS (SELECT 1 FROM ya_bi9_post_up AS Post WHERE Person.id = Post.CreatorPersonId);
CREATE OR REPLACE TEMP VIEW ya_bi9_post_down AS
SELECT Post.* FROM ya_bi9_post_up AS Post
WHERE EXISTS (SELECT 1 FROM ya_bi9_person_down AS Person WHERE Person.id = Post.CreatorPersonId);
CREATE OR REPLACE TEMP VIEW ya_bi9_mpp_down AS
SELECT MPP.* FROM ya_bi9_mpp_up AS MPP
WHERE EXISTS (SELECT 1 FROM ya_bi9_post_down AS Post WHERE Post.id = MPP.RootPostId);

SELECT Person.id AS "person.id",
       Person.firstName AS "person.firstName",
       Person.lastName AS "person.lastName",
       count(Post.id) AS threadCount,
       sum(MPP.MessageCount) AS messageCount
FROM ya_bi9_person_down AS Person
JOIN ya_bi9_post_down AS Post ON Person.id = Post.CreatorPersonId
JOIN ya_bi9_mpp_down AS MPP ON Post.id = MPP.RootPostId
WHERE Post.creationDate BETWEEN :startDate AND :endDate
GROUP BY Person.id, Person.firstName, Person.lastName;
