# Docker Images

> 🌐 Language / Ngôn ngữ: [English](DOCKER_IMAGES.md) | **Tiếng Việt**

Hướng dẫn này giải thích cách build và publish **container image Linux đa kiến trúc**
cho ứng dụng lên **GitHub Container Registry (GHCR)**.

Các image được publish hướng tới:

- `linux/amd64` — máy chủ Linux Intel/AMD x86-64, Mac Intel thông qua Docker Desktop,
  và hầu hết PC Windows thông qua Docker Desktop/WSL2 sử dụng container Linux.
- `linux/arm64` — máy chủ Linux ARM64, Mac Apple Silicon thông qua Docker Desktop,
  và hệ thống Windows ARM64 sử dụng container Linux.

Với người dùng Docker hiện đại, hai nền tảng này bao phủ phần lớn các cài đặt Docker
trên desktop, server, cloud, macOS và Windows. Đây là các **container image Linux**,
không phải container image Windows gốc.

Một khi gói GHCR được đặt ở chế độ **public**, bất kỳ ai cũng có thể pull nó ẩn danh
mà không cần đăng nhập GitHub hay package token.

## Tổng quan

Có hai biến thể image có thể publish, mỗi biến thể dành cho một backend database:

| Image | Database | Build từ tag | Commit |
| --- | --- | --- | --- |
| `ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres` | PostgreSQL 17 | `postgresql-baseline-v1` | `e7565fd` |
| `ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite` | SQLite | `sqlite-baseline-v1` | `700edca` |

Cả hai image có cùng hành vi runtime:

- Expose port **80** — Thruster đứng trước Puma (`./bin/thrust ./bin/rails server`).
- Entrypoint chạy `db:prepare`, nên database được tạo/migrate ở lần khởi động đầu tiên.
- **Không đóng gói secret nào**: chỉ `RAILS_ENV=production` được baked vào. Database URLs,
  `SECRET_KEY_BASE`, và admin credentials phải được cung cấp lúc runtime thông qua
  environment variables (Docker build bỏ qua `.env*` và `config/master.key`).
- Được build từ các **Git baseline tag** bất biến, nên có thể khôi phục chính xác mã
  nguồn ứng dụng dùng cho mỗi biến thể được publish. Lưu ý rằng điều này tự thân nó
  không làm cho toàn bộ Docker build tái lập bit-for-bit vì các tag base image gốc
  và các gói hệ điều hành có thể thay đổi theo thời gian.

## Mục tiêu tương thích

Manifest được publish đề xuất gồm:

```text
linux/amd64
linux/arm64
```

Điều này cho người dùng một image tag để pull. Docker tự động chọn đúng nền tảng từ
multi-platform manifest cho máy của host.

Ví dụ:

| Máy của người dùng | Image được chọn |
| --- | --- |
| Linux trên Intel/AMD | `linux/amd64` |
| Linux ARM64 / AWS Graviton | `linux/arm64` |
| macOS Intel + Docker Desktop | `linux/amd64` |
| macOS Apple Silicon + Docker Desktop | `linux/arm64` |
| Windows x86-64 + Docker Desktop/WSL2 | `linux/amd64` |
| Windows ARM64 + Docker Desktop | `linux/arm64` |

ARM 32-bit, x86 32-bit, PowerPC, s390x, RISC-V, và Windows container gốc nằm ngoài
phạm vi hỗ trợ trừ khi chúng được build và test tường minh về sau.

## Chiến lược tag được khuyến nghị

Publish một moving tag tiện lợi cùng với các tag bất biến/theo phiên bản cụ thể.

PostgreSQL:

```text
ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres
ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres-v1
ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres-e7565fd
```

SQLite:

```text
ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite
ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite-v1
ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite-700edca
```

Người dùng muốn biến thể hiện tại có thể dùng `:postgres` hoặc `:sqlite`. Người dùng
muốn deployment ổn định nên pin một version tag hoặc commit tag.

## Yêu cầu để publish thủ công

- Docker có Buildx được bật (`docker buildx version`).
- Các Git baseline tag có sẵn ở local: `git fetch --tags`.
- Để publish qua command line lên GHCR: một **GitHub Personal Access Token (classic)**
  có scope `write:packages`, thuộc về `dangkhoa2016` hoặc tài khoản đích.
- Docker Desktop thường tự cung cấp hỗ trợ emulation cần thiết. Trên Linux Docker
  Engine host, có thể cần cài QEMU/binfmt khi build một kiến trúc khác với kiến
  trúc của host.

> Xác thực GitHub Packages cho việc publish qua command line dùng Personal Access
> Token **(classic)**. Không ghi lại một fine-grained `packages:write` token như là
> thay thế cho luồng đăng nhập GHCR này.

## Bước 1 — Đăng nhập GHCR để publish thủ công

Lưu classic PAT trong một environment variable thay vì đặt trực tiếp vào
shell history:

```bash
echo "$PAT" | docker login ghcr.io -u dangkhoa2016 --password-stdin
```

Không bao giờ commit hay baked PAT vào trong Docker image.

> Nếu publish bằng GitHub Actions từ chính repository, hãy ưu tiên `GITHUB_TOKEN`
> của workflow; một personal PAT thường không cần thiết cho workflow đó.

## Bước 2 — Tạo builder đa kiến trúc

Tạo builder một lần:

```bash
docker buildx create --name multiarch --driver docker-container --use
docker buildx inspect --bootstrap
```

Nếu `multiarch` đã tồn tại, tái sử dụng nó:

```bash
docker buildx use multiarch
docker buildx inspect --bootstrap
```

### QEMU / emulation

Trên **Docker Desktop**, thường không cần cài QEMU thủ công.

Trên **Linux Docker Engine**, nếu builder không thể build `linux/arm64` từ host x86-64
(hoặc ngược lại), hãy cài binfmt/QEMU rồi bootstrap builder lại:

```bash
docker run --privileged --rm tonistiigi/binfmt --install arm64
docker buildx inspect --bootstrap
```

Kiểm tra các nền tảng mà builder hỗ trợ:

```bash
docker buildx inspect
```

Danh sách nền tảng nên bao gồm cả `linux/amd64` và `linux/arm64`.

## Bước 3 — Build và push các image

Build từ các Git baseline tag bất biến để mỗi biến thể được publish dùng chính xác mã
nguồn ứng dụng gắn với baseline đó.

```bash
REPOSITORY="https://github.com/dangkhoa2016/rails-8-api-authentication"

TMP="$(mktemp -d)"
git archive postgresql-baseline-v1 | tar -x -C "$TMP"

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --label "org.opencontainers.image.source=$REPOSITORY" \
  --label "org.opencontainers.image.revision=e7565fd" \
  -t ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres \
  -t ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres-v1 \
  -t ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres-e7565fd \
  --push "$TMP"

rm -rf "$TMP"

TMP="$(mktemp -d)"
git archive sqlite-baseline-v1 | tar -x -C "$TMP"

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --label "org.opencontainers.image.source=$REPOSITORY" \
  --label "org.opencontainers.image.revision=700edca" \
  -t ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite \
  -t ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite-v1 \
  -t ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite-700edca \
  --push "$TMP"

rm -rf "$TMP"
```

Ghi chú:

- `--push` publish trực tiếp multi-platform manifest; không cần `docker tag`
  hay `docker push` riêng.
- Docker sẽ tự động pull đúng kiến trúc khi người dùng pull một trong các tag
  này.
- OCI `org.opencontainers.image.source` label gắn metadata của image với repository
  nguồn và giúp artifact được publish dễ truy vết hơn.
- Image chính thức `ruby:3.3-slim` là đa kiến trúc. Ứng dụng và toàn bộ native
  dependencies vẫn phải build thành công trên mọi nền tảng bạn publish.
- Để build từ working tree hiện tại, hãy thay context thư mục tạm bằng `.`. Chỉ làm
  điều này khi bạn cố ý publish mã nguồn chưa được tag.
- Chỉ thêm `--provenance=false` nếu tooling downstream cụ thể không xử lý được build
  attestations. Ngược lại hãy giữ hành vi provenance mặc định.

## Bước 4 — Xác minh các multi-platform manifest đã publish

Đừng cho rằng một push đã tạo ra cả hai kiến trúc. Hãy kiểm tra từng tag được publish:

```bash
docker buildx imagetools inspect \
  ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres

docker buildx imagetools inspect \
  ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite
```

Mỗi kết quả nên chứa cả hai:

```text
linux/amd64
linux/arm64
```

Bạn cũng có thể test pull cho từng kiến trúc một cách tường minh trên máy có hỗ trợ
native hoặc emulation phù hợp:

```bash
docker pull --platform linux/amd64 \
  ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite

docker pull --platform linux/arm64 \
  ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite
```

## Bước 5 — Đưa gói GHCR sang chế độ public

Khi một gói GHCR được publish lần đầu, độ hiển thị mặc định của nó là **private**.
Hãy đổi sang **Public** trước khi mong người dùng ẩn danh pull được.

Trong GitHub:

1. Mở trang gói của `rails-8-api-authentication`.
2. Mở **Package settings**.
3. Trong mục **Danger Zone**, chọn **Change visibility**.
4. Đổi gói sang **Public**.
5. Xác nhận thay đổi độ hiển thị.

Một container package GHCR public có thể được pull ẩn danh, nên người dùng cuối không
cần tài khoản GitHub, PAT, hay `docker login` chỉ để chạy image.

Sau khi đưa gói sang public, hãy xác minh ẩn danh từ một Docker client đã đăng xuất:

```bash
docker logout ghcr.io 2>/dev/null || true
docker pull ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite
docker pull ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres
```

## Bước 6 — Chạy các image

Để tương thích cross-platform rộng nhất, hãy ưu tiên `--env-file` hơn cú pháp
environment-variable inline đặc thù theo shell. Nó hoạt động nhất quán với Docker CLI
trên Linux, macOS, Windows PowerShell, WSL, và các môi trường phổ biến khác.

### Tạo một production secret

Lệnh này dùng chính Ruby Docker image, nên host không cần OpenSSL:

```bash
docker run --rm ruby:3.3-slim \
  ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'
```

Copy giá trị đã tạo vào một environment file local **không được commit**.

### Image PostgreSQL

Ứng dụng xác thực lúc boot rằng cả bốn database tồn tại và tách biệt
(`config/initializers/production_database_urls.rb`). Tạo các database `_cache`, `_queue`,
và `_cable` trước trên PostgreSQL server; database chính được tạo bởi `db:prepare` theo
luồng khởi động hiện tại của ứng dụng.

Tạo `.env.production.local`:

```dotenv
SECRET_KEY_BASE=replace-with-a-random-secret
DATABASE_URL=postgres://user:password@dbhost:5432/rails_8_api_authentication_production
CACHE_DATABASE_URL=postgres://user:password@dbhost:5432/rails_8_api_authentication_production_cache
QUEUE_DATABASE_URL=postgres://user:password@dbhost:5432/rails_8_api_authentication_production_queue
CABLE_DATABASE_URL=postgres://user:password@dbhost:5432/rails_8_api_authentication_production_cable
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=change-me
```

Chạy:

```bash
docker run -d \
  --name rails-postgres \
  --env-file .env.production.local \
  -p 80:80 \
  ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres
```

Nếu PostgreSQL chạy trực tiếp trên Docker host thay vì trên một server/container khác
có thể truy cập được, cách xử lý hostname khác nhau tuỳ theo host OS. Docker Desktop
thường cung cấp `host.docker.internal`; người dùng Linux Engine có thể cần một host-gateway
mapping tường minh hoặc một Docker network.

### Image SQLite

Tạo `.env.production.local`:

```dotenv
SECRET_KEY_BASE=replace-with-a-random-secret
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=change-me
```

Chạy:

```bash
docker run -d \
  --name rails-sqlite \
  --env-file .env.production.local \
  -p 80:80 \
  -v rails_storage:/rails/storage \
  ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite
```

Các file database SQLite nằm trong `/rails/storage` bên trong container. Named volume
giữ chúng qua các lần tạo lại container.

### `SECRET_KEY_BASE` và `RAILS_MASTER_KEY`

`RAILS_MASTER_KEY` **không phải** cùng một secret với `SECRET_KEY_BASE`.

- `RAILS_MASTER_KEY` giải mã Rails encrypted credentials.
- `SECRET_KEY_BASE` là application secret của Rails dùng để ký mật mã.
- Bạn chỉ có thể bỏ qua environment variable `SECRET_KEY_BASE` khi có một
  `RAILS_MASTER_KEY` hợp lệ được cung cấp **và** Rails encrypted credentials có chứa
  một giá trị `secret_key_base` dùng được cho production application.

Với một image ví dụ công khai cố ý không đóng gói master key riêng tư, việc cung cấp
`SECRET_KEY_BASE` lúc runtime là mô hình deployment đơn giản hơn.

### Xác minh

```bash
curl -s http://localhost/up
```

Kết quả mong đợi: HTTP `200 OK`.

Sau đó đăng nhập bằng admin credentials đã cấu hình.

## Khuyến nghị — Publish tự động với GitHub Actions

Với một GitHub repository public, GitHub Actions được ưu tiên hơn việc publish thủ công
từ một workstation của developer. Workflow có thể dùng `GITHUB_TOKEN` với `packages: write`
thay vì lưu trữ một personal PAT cho việc publish thường xuyên thuộc repository.

Một repository workflow có thể dùng matrix để build từng baseline thành một image
đa nền tảng. Ví dụ:

```yaml
name: Publish Docker images

on:
  workflow_dispatch:
  push:
    tags:
      - "docker-*"

permissions:
  contents: read
  packages: write

jobs:
  publish:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        include:
          - variant: postgres
            ref: postgresql-baseline-v1
            version: postgres-v1
            commit_tag: postgres-e7565fd
            source_commit: e7565fd
          - variant: sqlite
            ref: sqlite-baseline-v1
            version: sqlite-v1
            commit_tag: sqlite-700edca
            source_commit: 700edca

    steps:
      - name: Check out baseline
        uses: actions/checkout@v7
        with:
          ref: ${{ matrix.ref }}

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v7
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: |
            ghcr.io/dangkhoa2016/rails-8-api-authentication:${{ matrix.variant }}
            ghcr.io/dangkhoa2016/rails-8-api-authentication:${{ matrix.version }}
            ghcr.io/dangkhoa2016/rails-8-api-authentication:${{ matrix.commit_tag }}
          labels: |
            org.opencontainers.image.source=https://github.com/dangkhoa2016/rails-8-api-authentication
            org.opencontainers.image.revision=${{ matrix.source_commit }}
```

Với các production workflow lâu dài, hãy cân nhắc pin các GitHub Actions của bên thứ ba
vào full commit SHA thay vì các version tag đang di chuyển. GitHub tường minh khuyến nghị
điều này để ổn định supply-chain.

Sau lần publish workflow đầu tiên, vẫn phải xác minh rằng độ hiển thị của gói GHCR là
**Public** nếu cần pull ẩn danh.

## Xử lý sự cố

- **`exec format error` trên máy ARM** — kiểm tra GHCR manifest. Tag có thể chỉ chứa
  `linux/amd64`; hãy publish lại với cả `linux/amd64` và `linux/arm64`.
- **401 Unauthorized khi `docker pull`** — xác minh gói GHCR thực sự đã là Public.
  Các gói Container registry công khai hỗ trợ pull ẩn danh.
- **Repository public hiển thị nhưng `docker pull` vẫn yêu cầu xác thực** — độ hiển thị
  của repository và độ hiển thị của gói là hai khái niệm tách biệt. Kiểm tra cài đặt
  riêng của gói.
- **Build `arm64` chậm trên builder x86-64** — QEMU emulation chậm hơn builder ARM64
  native. Điều này là bình thường.
- **Build chạy được trên `amd64` nhưng fail trên `arm64`** — kiểm tra native gems, các
  gói OS, và bất kỳ binary precompiled nào. Một base image đa kiến trúc tự thân không
  đảm bảo mọi application dependency hỗ trợ mọi kiến trúc.
- **Builder không liệt kê `linux/arm64`** — trên Linux Engine, hãy cài binfmt/QEMU và
  chạy lại `docker buildx inspect --bootstrap`. Docker Desktop thường tự xử lý việc
  này.
- **Người dùng Windows không thể chạy image như một Windows container gốc** — dự án này
  publish các Linux container. Người dùng Windows nên chạy Docker Desktop/WSL2 ở chế độ
  Linux container.

## Tài liệu tham khảo chính thức

- Docker multi-platform builds: https://docs.docker.com/build/building/multi-platform/
- Docker multi-platform GitHub Actions: https://docs.docker.com/build/ci/github-actions/multi-platform/
- GitHub Container registry: https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry
- GitHub package permissions and visibility: https://docs.github.com/packages/learn-github-packages/about-permissions-for-github-packages
- GitHub Actions Docker publishing: https://docs.github.com/actions/guides/publishing-docker-images
- Rails credentials/security: https://guides.rubyonrails.org/security.html
