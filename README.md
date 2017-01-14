#### Track Rightscale input versions

Setup

1. Create rightscale.yml in jobs folder, example file provided
2. Create schema in mysql
3. Set environment variables
   1. DBHOST
   2. DBNAME
   3. DBUSER
   4. DBPASS
4. bundle install
5. rackup
6. `curl URL_TO_APP/update` (this will perform the initial pull from all accounts in rightscale.yml)
7. perform updates on a schedule using same route 👆🏿
8. ????
9. profit
