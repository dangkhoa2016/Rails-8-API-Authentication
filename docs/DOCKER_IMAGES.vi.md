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
| `ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres` | PostgreSQL 17 | `postgresql-baseline-v1` | `9d4a7f0` |
| `ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite` | SQLite | `sqlite-baseline-v1` | `34ae7e6` |

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

> Cột `Commit` liệt kê `HEAD` hiện tại của mỗi baseline tag. Các baseline tag là
> **annotated tag**, và giá trị hiển thị là commit mà tag trỏ tới
> (`git rev-parse <tag>^{commit}`), tức commit mà một checkout sẽ giải quyết ra — chứ
> không phải hash của bản thân tag object (`git rev-parse <tag>`). Workflow giải quyết
> short SHA tại thời điểm publish (`git rev-parse --short=7 HEAD`), nên tag `-<sha>`
> và label `org.opencontainers.image.revision` luôn phản ánh chính xác commit nguồn
> đằng sau image được publish.

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
ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres-64d8f32
ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres-amd64
ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres-arm64
```

SQLite:

```text
ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite
ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite-v1
ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite-34ae7e6
ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite-amd64
ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite-arm64
```

Người dùng muốn biến thể hiện tại có thể dùng `:postgres` hoặc `:sqlite`. Người dùng
muốn deployment ổn định nên pin một version tag hoặc commit tag.

Tag `-<sha>` được tạo tại thời điểm publish từ `HEAD` của từng baseline tag, nên nó
luôn phản ánh chính xác commit nguồn phía sau image được publish. Các alias
`:postgres-amd64` / `:postgres-arm64` và `:sqlite-amd64` / `:sqlite-arm64` trỏ tới
cùng các platform manifest được publish, tiện khi xem từng kiến trúc trên trang
"Versions" của GHCR.

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
REPOSITORY="https://github.com/dangkhoa2016/Rails-8-API-Authentication"

TMP="$(mktemp -d)"
git archive postgresql-baseline-v1 | tar -x -C "$TMP"

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --label "org.opencontainers.image.source=$REPOSITORY" \
  --label "org.opencontainers.image.revision=64d8f32" \
  -t ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres \
  -t ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres-v1 \
  -t ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres-64d8f32 \
  --push "$TMP"

rm -rf "$TMP"

TMP="$(mktemp -d)"
git archive sqlite-baseline-v1 | tar -x -C "$TMP"

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --label "org.opencontainers.image.source=$REPOSITORY" \
  --label "org.opencontainers.image.revision=34ae7e6" \
  -t ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite \
  -t ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite-v1 \
  -t ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite-34ae7e6 \
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
đa nền tảng. Dự án cung cấp workflow này trong `.github/workflows/publish-docker-images.yml`:

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

# Prevent duplicate runs for the same Git ref from publishing concurrently.
concurrency:
  group: publish-docker-images-${{ github.ref }}
  cancel-in-progress: true

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: dangkhoa2016/rails-8-api-authentication
  IMAGE_SOURCE: https://github.com/dangkhoa2016/Rails-8-API-Authentication
  IMAGE_LICENSE: MIT

jobs:
  publish:
    name: Build and publish ${{ matrix.variant }}
    runs-on: ubuntu-latest

    strategy:
      fail-fast: false
      matrix:
        include:
          - variant: postgres
            ref: postgresql-baseline-v1
            version: postgres-v1
            title: Rails 8 API Authentication - PostgreSQL
            description: Rails 8 API authentication service with Devise, JWT, and PostgreSQL support.

          - variant: sqlite
            ref: sqlite-baseline-v1
            version: sqlite-v1
            title: Rails 8 API Authentication - SQLite
            description: Rails 8 API authentication service with Devise, JWT, and SQLite support.

    steps:
      - name: Check out ${{ matrix.variant }} baseline
        uses: actions/checkout@v7
        with:
          ref: ${{ matrix.ref }}

      # Resolve the exact commit behind the checked-out baseline instead of
      # hard-coding a short SHA in the workflow.
      - name: Resolve source revision
        id: source
        shell: bash
        run: |
          echo "sha=$(git rev-parse HEAD)" >> "$GITHUB_OUTPUT"
          echo "short_sha=$(git rev-parse --short=7 HEAD)" >> "$GITHUB_OUTPUT"

      # QEMU is required to build ARM64 images on the default AMD64 GitHub runner.
      - name: Set up QEMU
        uses: docker/setup-qemu-action@v4
        with:
          platforms: arm64

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v4

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v4
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push ${{ matrix.variant }} image
        uses: docker/build-push-action@v7
        with:
          context: .
          file: ./Dockerfile
          platforms: linux/amd64,linux/arm64
          push: true

          # Publish:
          #   1. A stable database-variant tag
          #   2. A versioned alias
          #   3. An immutable source-commit alias
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ matrix.variant }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ matrix.version }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ matrix.variant }}-${{ steps.source.outputs.short_sha }}

          # OCI labels are stored in the image configuration of each runnable
          # platform image and can be inspected with tools such as docker inspect.
          labels: |
            org.opencontainers.image.title=${{ matrix.title }}
            org.opencontainers.image.description=${{ matrix.description }}
            org.opencontainers.image.source=${{ env.IMAGE_SOURCE }}
            org.opencontainers.image.url=${{ env.IMAGE_SOURCE }}
            org.opencontainers.image.licenses=${{ env.IMAGE_LICENSE }}
            org.opencontainers.image.version=${{ matrix.version }}
            org.opencontainers.image.revision=${{ steps.source.outputs.sha }}

          # Generic metadata for the multi-platform index, plus platform-specific
          # metadata for each runnable child manifest. This makes direct GHCR
          # digest pages clearly identify linux/amd64 or linux/arm64.
          annotations: |
            index:org.opencontainers.image.title=${{ matrix.title }}
            index:org.opencontainers.image.description=${{ matrix.description }}
            index:org.opencontainers.image.source=${{ env.IMAGE_SOURCE }}
            index:org.opencontainers.image.url=${{ env.IMAGE_SOURCE }}
            index:org.opencontainers.image.licenses=${{ env.IMAGE_LICENSE }}
            index:org.opencontainers.image.version=${{ matrix.version }}
            index:org.opencontainers.image.revision=${{ steps.source.outputs.sha }}

            manifest[linux/amd64]:org.opencontainers.image.title=${{ matrix.title }} - linux/amd64
            manifest[linux/amd64]:org.opencontainers.image.description=${{ matrix.description }} Platform: linux/amd64.
            manifest[linux/amd64]:org.opencontainers.image.source=${{ env.IMAGE_SOURCE }}
            manifest[linux/amd64]:org.opencontainers.image.url=${{ env.IMAGE_SOURCE }}
            manifest[linux/amd64]:org.opencontainers.image.licenses=${{ env.IMAGE_LICENSE }}
            manifest[linux/amd64]:org.opencontainers.image.version=${{ matrix.version }}
            manifest[linux/amd64]:org.opencontainers.image.revision=${{ steps.source.outputs.sha }}

            manifest[linux/arm64]:org.opencontainers.image.title=${{ matrix.title }} - linux/arm64
            manifest[linux/arm64]:org.opencontainers.image.description=${{ matrix.description }} Platform: linux/arm64.
            manifest[linux/arm64]:org.opencontainers.image.source=${{ env.IMAGE_SOURCE }}
            manifest[linux/arm64]:org.opencontainers.image.url=${{ env.IMAGE_SOURCE }}
            manifest[linux/arm64]:org.opencontainers.image.licenses=${{ env.IMAGE_LICENSE }}
            manifest[linux/arm64]:org.opencontainers.image.version=${{ matrix.version }}
            manifest[linux/arm64]:org.opencontainers.image.revision=${{ steps.source.outputs.sha }}

          # Keep independent BuildKit caches for PostgreSQL and SQLite so the
          # matrix jobs do not overwrite each other's GitHub Actions cache.
          cache-from: type=gha,scope=rails-auth-${{ matrix.variant }}
          cache-to: type=gha,mode=max,scope=rails-auth-${{ matrix.variant }}

          # Keep SLSA provenance metadata for supply-chain verification.
          # GHCR may list the resulting attestation manifests as untagged
          # package versions; those artifacts are metadata, not runnable images.
          provenance: mode=max

      # Add human-readable tags directly to the existing platform manifests.
      #
      # These aliases improve the GHCR "Versions" page because the four runnable
      # child manifests no longer appear only as anonymous sha256 digests:
      #
      #   postgres-amd64
      #   postgres-arm64
      #   sqlite-amd64
      #   sqlite-arm64
      #
      # No image is rebuilt here. The existing child manifests are simply given
      # additional tags.
      - name: Tag platform-specific images
        shell: bash
        env:
          IMAGE: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          VARIANT: ${{ matrix.variant }}
        run: |
          set -euo pipefail

          INDEX="${IMAGE}:${VARIANT}"

          echo "Inspecting multi-platform image: ${INDEX}"

          # Read the OCI image index and locate the two runnable platform
          # manifests. Provenance manifests are ignored because they use
          # unknown/unknown as their platform.
          INDEX_JSON="$(docker buildx imagetools inspect "${INDEX}" --raw)"

          AMD64_DIGEST="$(
            jq -r '
              .manifests[]
              | select(
                  .platform.os == "linux"
                  and .platform.architecture == "amd64"
                )
              | .digest
            ' <<< "${INDEX_JSON}"
          )"

          ARM64_DIGEST="$(
            jq -r '
              .manifests[]
              | select(
                  .platform.os == "linux"
                  and .platform.architecture == "arm64"
                )
              | .digest
            ' <<< "${INDEX_JSON}"
          )"

          if [[ -z "${AMD64_DIGEST}" || "${AMD64_DIGEST}" == "null" ]]; then
            echo "::error::Could not find the linux/amd64 manifest digest."
            exit 1
          fi

          if [[ -z "${ARM64_DIGEST}" || "${ARM64_DIGEST}" == "null" ]]; then
            echo "::error::Could not find the linux/arm64 manifest digest."
            exit 1
          fi

          echo "linux/amd64 digest: ${AMD64_DIGEST}"
          echo "linux/arm64 digest: ${ARM64_DIGEST}"

          # --prefer-index=false preserves each source as a single-platform
          # manifest instead of wrapping it in another image index.
          docker buildx imagetools create             --prefer-index=false             --tag "${IMAGE}:${VARIANT}-amd64"             "${IMAGE}@${AMD64_DIGEST}"

          docker buildx imagetools create             --prefer-index=false             --tag "${IMAGE}:${VARIANT}-arm64"             "${IMAGE}@${ARM64_DIGEST}"

      - name: Verify published tags
        shell: bash
        env:
          IMAGE: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          VARIANT: ${{ matrix.variant }}
        run: |
          set -euo pipefail

          echo "Multi-platform tag:"
          docker buildx imagetools inspect "${IMAGE}:${VARIANT}"

          echo
          echo "AMD64 tag:"
          docker buildx imagetools inspect "${IMAGE}:${VARIANT}-amd64"

          echo
          echo "ARM64 tag:"
          docker buildx imagetools inspect "${IMAGE}:${VARIANT}-arm64"
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
