# Gurumeet

製作中

## GitHub Actions secrets

Cloudflare deploy と Worker / Container の runtime secrets は GitHub Actions から渡す。

Repository secrets:

```text
CLOUDFLARE_API_TOKEN
CLOUDFLARE_ACCOUNT_ID
```

GitHub Environment secrets:

```text
staging:
  DATABASE_URL
  HOTPEPPER_API_KEY
  PARTICIPANT_TOKEN_HASH_SECRET

production:
  DATABASE_URL
  HOTPEPPER_API_KEY
  PARTICIPANT_TOKEN_HASH_SECRET
```

登録手順は `infra/cloudflare/README.md` を参照する。
