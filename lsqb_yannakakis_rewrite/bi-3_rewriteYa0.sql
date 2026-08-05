-- Locally simulated DuckDB Yannakakis-style two-pass reduction.
-- The tag branch remains EXISTS so multiple matching tags never multiply Message rows.
CREATE OR REPLACE TEMP VIEW ya_bi3_country_up AS
SELECT Country.* FROM Country WHERE Country.name = :country;
CREATE OR REPLACE TEMP VIEW ya_bi3_city_up AS
SELECT City.* FROM City
WHERE EXISTS (SELECT 1 FROM ya_bi3_country_up AS Country WHERE Country.id = City.PartOfCountryId);
CREATE OR REPLACE TEMP VIEW ya_bi3_moderator_up AS
SELECT ModeratorPerson.* FROM Person AS ModeratorPerson
WHERE EXISTS (SELECT 1 FROM ya_bi3_city_up AS City WHERE City.id = ModeratorPerson.LocationCityId);
CREATE OR REPLACE TEMP VIEW ya_bi3_forum_up AS
SELECT Forum.* FROM Forum
WHERE EXISTS (SELECT 1 FROM ya_bi3_moderator_up AS ModeratorPerson WHERE ModeratorPerson.id = Forum.ModeratorPersonId);
CREATE OR REPLACE TEMP VIEW ya_bi3_tagclass_up AS
SELECT TagClass.* FROM TagClass WHERE TagClass.name = :tagClass;
CREATE OR REPLACE TEMP VIEW ya_bi3_tag_up AS
SELECT Tag.* FROM Tag
WHERE EXISTS (SELECT 1 FROM ya_bi3_tagclass_up AS TagClass WHERE Tag.TypeTagClassId = TagClass.id);
CREATE OR REPLACE TEMP VIEW ya_bi3_message_tag_up AS
SELECT Message_hasTag_Tag.* FROM Message_hasTag_Tag
WHERE EXISTS (SELECT 1 FROM ya_bi3_tag_up AS Tag WHERE Message_hasTag_Tag.TagId = Tag.id);
CREATE OR REPLACE TEMP VIEW ya_bi3_message_down AS
SELECT Message.* FROM Message
WHERE EXISTS (SELECT 1 FROM ya_bi3_forum_up AS Forum WHERE Forum.id = Message.ContainerForumId)
  AND EXISTS (SELECT 1 FROM ya_bi3_message_tag_up AS Message_hasTag_Tag WHERE Message.MessageId = Message_hasTag_Tag.MessageId);
CREATE OR REPLACE TEMP VIEW ya_bi3_forum_down AS
SELECT Forum.* FROM ya_bi3_forum_up AS Forum
WHERE EXISTS (SELECT 1 FROM ya_bi3_message_down AS Message WHERE Forum.id = Message.ContainerForumId);
CREATE OR REPLACE TEMP VIEW ya_bi3_moderator_down AS
SELECT ModeratorPerson.* FROM ya_bi3_moderator_up AS ModeratorPerson
WHERE EXISTS (SELECT 1 FROM ya_bi3_forum_down AS Forum WHERE ModeratorPerson.id = Forum.ModeratorPersonId);
CREATE OR REPLACE TEMP VIEW ya_bi3_city_down AS
SELECT City.* FROM ya_bi3_city_up AS City
WHERE EXISTS (SELECT 1 FROM ya_bi3_moderator_down AS ModeratorPerson WHERE City.id = ModeratorPerson.LocationCityId);
CREATE OR REPLACE TEMP VIEW ya_bi3_country_down AS
SELECT Country.* FROM ya_bi3_country_up AS Country
WHERE EXISTS (SELECT 1 FROM ya_bi3_city_down AS City WHERE Country.id = City.PartOfCountryId);
CREATE OR REPLACE TEMP VIEW ya_bi3_message_tag_down AS
SELECT Message_hasTag_Tag.* FROM ya_bi3_message_tag_up AS Message_hasTag_Tag
WHERE EXISTS (SELECT 1 FROM ya_bi3_message_down AS Message WHERE Message.MessageId = Message_hasTag_Tag.MessageId);
CREATE OR REPLACE TEMP VIEW ya_bi3_tag_down AS
SELECT Tag.* FROM ya_bi3_tag_up AS Tag
WHERE EXISTS (SELECT 1 FROM ya_bi3_message_tag_down AS Message_hasTag_Tag WHERE Message_hasTag_Tag.TagId = Tag.id);
CREATE OR REPLACE TEMP VIEW ya_bi3_tagclass_down AS
SELECT TagClass.* FROM ya_bi3_tagclass_up AS TagClass
WHERE EXISTS (SELECT 1 FROM ya_bi3_tag_down AS Tag WHERE Tag.TypeTagClassId = TagClass.id);

SELECT Forum.id AS "forum.id",
       Forum.title AS "forum.title",
       Forum.creationDate AS "forum.creationDate",
       Forum.ModeratorPersonId AS "person.id",
       count(Message.MessageId) AS messageCount
FROM ya_bi3_message_down AS Message
JOIN ya_bi3_forum_down AS Forum ON Forum.id = Message.ContainerForumId
JOIN ya_bi3_moderator_down AS ModeratorPerson ON ModeratorPerson.id = Forum.ModeratorPersonId
JOIN ya_bi3_city_down AS City ON City.id = ModeratorPerson.LocationCityId
JOIN ya_bi3_country_down AS Country ON Country.id = City.PartOfCountryId AND Country.name = :country
WHERE EXISTS (
  SELECT 1
  FROM ya_bi3_tagclass_down AS TagClass
  JOIN ya_bi3_tag_down AS Tag ON Tag.TypeTagClassId = TagClass.id
  JOIN ya_bi3_message_tag_down AS Message_hasTag_Tag ON Message_hasTag_Tag.TagId = Tag.id
  WHERE Message.MessageId = Message_hasTag_Tag.MessageId AND TagClass.name = :tagClass)
GROUP BY Forum.id, Forum.title, Forum.creationDate, Forum.ModeratorPersonId;
