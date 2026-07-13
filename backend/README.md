# backend

ここはbackendの処理を書くフォルダです

## 起動

repository root から:

```sh
docker compose -f backend/docker/compose.yaml up --build
```

`backend` フォルダ内から:

```sh
docker compose -f docker/compose.yaml up --build
```

API:

- `http://localhost:8000/`
- `http://localhost:8000/health`
- `http://localhost:8000/docs`

停止:

```sh
docker compose -f backend/docker/compose.yaml down
```
