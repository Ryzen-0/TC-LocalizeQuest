# TC-LocalizeQuest
 
When using "tc-localize-quest-batch.ps1" export (.csv) first missing translation records from DB by these queries.

```sql
SET @lang_code = "itIT";

-- "quest_request_items_locale" and "quest_offer_reward_locale" missing translation table
SELECT quest_request_items.ID AS globalID FROM quest_request_items
LEFT JOIN quest_request_items_locale ON quest_request_items_locale.ID=quest_request_items.ID
WHERE locale != @lang_code OR locale IS NULL
UNION 
SELECT quest_offer_reward.ID AS globalID FROM quest_offer_reward
 LEFT JOIN quest_offer_reward_locale ON quest_offer_reward_locale.ID=quest_offer_reward.ID
 WHERE locale != @lang_code OR locale IS NULL
 LIMIT 50000;
```
