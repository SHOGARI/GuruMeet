# Database

DB定義の入口。

- [Database Overview](./database.md)
- [Anonymous Users Table](./anonymous-users.md)
- [Location Tables](./locations.md)
- [Temporary Groups Table](./temporary-groups.md)
- [Temporary Group Participants Table](./temporary-group-participants.md)

## ER図

現段階のSQLAlchemyモデルとAlembic migrationに基づくER図。

`location_search` は市区町村・駅を統合した検索用テーブルで、`source_id` は
`municipalities.id` または `stations.id` を指す論理参照です。DB上の物理FKではありません。
`temporary_groups.location_id` も `location_search.id` を保持する論理参照です。

```mermaid
erDiagram
    users {
        int id PK
        string name
        string email UK
        datetime created_at
    }

    anonymous_users {
        uuid id PK
        string participant_token_hash UK
        datetime created_at
        datetime last_seen_at
    }

    temporary_groups {
        uuid id PK
        char code UK
        string creator_id
        int participant_count
        string location
        string location_id
        string location_type
        string location_prefecture_name
        string location_municipality_name
        string location_municipality_code
        string location_station_code
        string location_station_group_code
        float location_latitude
        float location_longitude
        int location_radius_meters
        int budget_min
        int budget_max
        json restaurant
        string restaurant_search_status
        datetime voting_started_at
        datetime created_at
        datetime expires_at
    }

    temporary_group_participants {
        uuid id PK
        uuid temporary_group_id FK
        uuid anonymous_user_id FK
        datetime joined_at
        datetime last_seen_at
    }

    temporary_group_votes {
        uuid id PK
        uuid temporary_group_id FK
        uuid anonymous_user_id FK
        string restaurant_id
        boolean liked
        datetime created_at
        datetime updated_at
    }

    municipalities {
        int id PK
        string municipality_code UK
        string prefecture_name
        string municipality_name
        string name_kana
        float latitude
        float longitude
    }

    stations {
        int id PK
        string station_code UK
        string station_group_code
        string station_name
        string name_kana
        string prefecture_name
        string municipality_name
        float latitude
        float longitude
        string line_name
    }

    location_search {
        string id PK
        string location_type
        int source_id
        string name
        string name_kana
        string normalized_name
        string normalized_kana
        string display_name
        string prefecture_name
        string municipality_name
        float latitude
        float longitude
        string municipality_code
        string station_code
        string station_group_code
        string line_name
    }

    temporary_groups ||--o{ temporary_group_participants : has
    anonymous_users ||--o{ temporary_group_participants : joins
    temporary_groups ||--o{ temporary_group_votes : has
    anonymous_users ||--o{ temporary_group_votes : casts
    municipalities ||..o{ location_search : indexed_as
    stations ||..o{ location_search : indexed_as
    location_search ||..o{ temporary_groups : selected_by
```
