cd ~/prod-to-dev-migration
git fetch origin main
git reset --hard origin/main
chmod +x *
./setup.sh
./dump_prod_to_dev.sh
