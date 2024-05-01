cd ~/prod-to-dev-migration
git reset --hard origin/main
git pull origin main
./setup.sh
./dump_prod_to_dev.sh
