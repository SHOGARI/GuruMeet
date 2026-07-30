# Database

DB定義の入口。

- [Database Overview](./database.md)
- [Anonymous Users Table](./anonymous-users.md)
- [Location Tables](./locations.md)
- [Temporary Groups Table](./temporary-groups.md)
- [Temporary Group Participants Table](./temporary-group-participants.md)

## ER図

現段階のSQLAlchemyモデルとAlembic migrationに基づくER図。

地点は `locations` を親テーブルにし、市区町村と駅の固有情報を
`municipality_locations` / `station_locations` に分ける。
`temporary_groups` は選択された `locations.id` だけを保持する。

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
        string location_id FK
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

    locations {
        string id PK
        string location_type
        string name
        string name_kana
        string normalized_name
        string normalized_kana
        string display_name
        string prefecture_name
        string municipality_name
        float latitude
        float longitude
        string source
        datetime source_updated_at
    }

    municipality_locations {
        string location_id PK, FK
        string municipality_code UK
    }

    station_locations {
        string location_id PK, FK
        string station_code UK
        string station_group_code
        string line_name
    }

    temporary_groups ||--o{ temporary_group_participants : has
    anonymous_users ||--o{ temporary_group_participants : joins
    temporary_groups ||--o{ temporary_group_votes : has
    anonymous_users ||--o{ temporary_group_votes : casts
    locations ||--o| municipality_locations : has
    locations ||--o| station_locations : has
    locations ||--o{ temporary_groups : selected_by
```
