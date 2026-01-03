# Releasing

This gem uses `bundler/gem_tasks` to manage releases.

## Instructions

1.  Make sure your working directory is clean and you are on the `main` branch.
2.  Update the version in `lib/lookbook_visual_tester/version.rb`.
3.  Update the `CHANGELOG.md`.
4.  Run the release task:
    ```bash
    bundle exec rake release:otp
    ```
    This will:
    -   Create a git tag for the version.
    -   Push git commits and tags.
    -   Build the gem.
    -   Push the `.gem` file to RubyGems.org.

## Troubleshooting

If you encounter issues with authentication, ensure you are logged in to RubyGems via the `gem` CLI:
```bash
gem signin
```

If you need to supply a 2FA/OTP code manually or for a script, you can use the `release:otp` task or set the `GEM_HOST_OTP_CODE` environment variable:

```bash
GEM_HOST_OTP_CODE=123456 bundle exec rake release
```
