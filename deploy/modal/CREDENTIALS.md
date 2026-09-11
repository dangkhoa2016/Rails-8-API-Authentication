# Rails Production Credentials for Modal

The Modal deployment uses Rails' standard environment-specific production credentials:

```text
config/credentials/production.yml.enc   # encrypted ciphertext — commit this
config/credentials/production.key       # decryption key — never commit this
```

When `RAILS_ENV=production`, Rails automatically uses `config/credentials/production.yml.enc` when it exists. Locally Rails can decrypt it with `config/credentials/production.key`; on Modal the same key is supplied through `RAILS_MASTER_KEY`.

`config/credentials.yml.enc` is not merged with the production file. Therefore the production file must contain every credential the production runtime needs.

## Create or edit production credentials

Use the standard Rails workflow:

```bash
unset RAILS_MASTER_KEY
export EDITOR=nano
bin/rails credentials:edit --environment production
```

Rails creates or edits:

```text
config/credentials/production.yml.enc
config/credentials/production.key
```

The decrypted production credentials should include at least:

```yaml
secret_key_base: <long random Rails secret>
admin_email: <real admin email>
admin_password: <real admin password>
devise_jwt_secret_key: <long random Rails secret>
```

Generate independent secrets locally when needed:

```bash
bin/rails secret
```

Do not paste secret values into shell scripts, documentation, GitHub issues/PR comments, or chat.

## Commit only ciphertext

```bash
git status --short config/credentials/production.yml.enc config/credentials/production.key
git add config/credentials/production.yml.enc
git commit -m "chore(modal): add encrypted production credentials" \
  -m "- Store production admin and JWT credentials as Rails-encrypted ciphertext only"
```

`config/credentials/production.key` is ignored by `.gitignore` and must never be tracked.

Before deployment, `deploy/modal/deploy.sh` verifies that:

- `config/credentials/production.yml.enc` exists, is non-empty, and is tracked;
- the encrypted file has no uncommitted changes;
- `config/credentials/production.key` is not tracked.

## Modal runtime secret

The named Modal secret `rails-api-production` contains only:

- `RAILS_MASTER_KEY` — the exact contents of `config/credentials/production.key`;
- `DATABASE_URL`;
- `CACHE_DATABASE_URL`;
- `QUEUE_DATABASE_URL`;
- `CABLE_DATABASE_URL`.

Do not commit the JSON or shell material used to create that Modal secret.

## Runtime behavior

Modal sets `RAILS_ENV=production`, so Rails selects `config/credentials/production.yml.enc` through its normal production credentials lookup. No Modal-specific credentials loader or overlay is used.

The runtime executes `db:prepare` and then the existing idempotent `db:seed` before Puma starts. The seed code reads `Rails.application.credentials.admin_email` and `admin_password`, while Devise reads `Rails.application.credentials.devise_jwt_secret_key`.
