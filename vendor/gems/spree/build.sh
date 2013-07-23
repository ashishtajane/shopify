# Remove Gemfile.lock if it exists
function rm_gemfile_lock(){
 if [ -e "Gemfile.lock" ] 
 then
  echo "Removing Gemfile.lock..."
  rm Gemfile.lock
 fi 
}

# Switching Gemfile
function set_gemfile(){
  echo "Switching Gemfile..."
  export BUNDLE_GEMFILE="`pwd`/Gemfile"
}

# Spree defaults
echo "Setup Spree defaults and creating test application..."
rm_gemfile_lock
bundle check || bundle install
bundle exec rake test_app

# Spree API
echo "Setup Spree API and running RSpec..."
cd api; set_gemfile; rm_gemfile_lock; bundle install; bundle exec rspec spec

# Spree Backend
echo "Setup Spree backend and running RSpec..."
cd ../backend; set_gemfile; rm_gemfile_lock; bundle install; bundle exec rspec spec

# Spree Core
echo "Setup Spree core and running RSpec..."
cd ../core; set_gemfile; rm_gemfile_lock; bundle install; bundle exec rspec spec

# Spree Frontend
echo "Setup Spree frontend and running RSpec..."
cd ../frontend; set_gemfile; rm_gemfile_lock; bundle install; bundle exec rspec spec