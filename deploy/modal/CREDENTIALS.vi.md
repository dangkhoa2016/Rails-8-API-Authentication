# Rails Production Credentials cho Modal

Modal deployment dùng đúng convention environment-specific credentials của Rails:

```text
config/credentials/production.yml.enc   # ciphertext đã mã hóa — được commit
config/credentials/production.key       # key giải mã — tuyệt đối không commit
```

Khi `RAILS_ENV=production`, Rails tự động dùng `config/credentials/production.yml.enc` nếu file này tồn tại. Ở local Rails có thể giải mã bằng `config/credentials/production.key`; trên Modal cùng key đó được truyền qua `RAILS_MASTER_KEY`.

`config/credentials.yml.enc` không được merge với production credentials. Vì vậy `production.yml.enc` phải chứa đầy đủ credentials mà production runtime cần.

## Tạo hoặc sửa production credentials

Dùng workflow chuẩn của Rails:

```bash
unset RAILS_MASTER_KEY
export EDITOR=nano
bin/rails credentials:edit --environment production
```

Rails sẽ tạo hoặc sửa:

```text
config/credentials/production.yml.enc
config/credentials/production.key
```

Nội dung decrypted nên có tối thiểu:

```yaml
secret_key_base: <Rails secret dài và ngẫu nhiên>
admin_email: <admin email thật>
admin_password: <admin password thật>
devise_jwt_secret_key: <Rails secret dài và ngẫu nhiên>
```

Có thể tạo secret độc lập bằng:

```bash
bin/rails secret
```

Không dán secret vào shell script, tài liệu, GitHub issue/PR comment hoặc chat.

## Chỉ commit ciphertext

```bash
git status --short config/credentials/production.yml.enc config/credentials/production.key
git add config/credentials/production.yml.enc
git commit -m "chore(modal): add encrypted production credentials" \
  -m "- Store production admin and JWT credentials as Rails-encrypted ciphertext only"
```

`config/credentials/production.key` được `.gitignore` bỏ qua và tuyệt đối không được Git track.

Trước khi deploy, `deploy/modal/deploy.sh` kiểm tra:

- `config/credentials/production.yml.enc` phải tồn tại, không rỗng và đã được Git track;
- ciphertext không có thay đổi chưa commit;
- `config/credentials/production.key` không được Git track.

## Modal runtime secret

Named secret `rails-api-production` chỉ chứa:

- `RAILS_MASTER_KEY` — chính xác nội dung của `config/credentials/production.key`;
- `DATABASE_URL`;
- `CACHE_DATABASE_URL`;
- `QUEUE_DATABASE_URL`;
- `CABLE_DATABASE_URL`.

Không commit JSON/shell material dùng để tạo Modal secret.

## Hành vi runtime

Modal đặt `RAILS_ENV=production`, nên Rails tự chọn `config/credentials/production.yml.enc` theo lookup production chuẩn. Không còn custom Modal credentials loader/overlay.

Runtime chạy `db:prepare` rồi `db:seed` trước khi Puma start. Seed đọc `Rails.application.credentials.admin_email` và `admin_password`; Devise đọc `Rails.application.credentials.devise_jwt_secret_key`.
