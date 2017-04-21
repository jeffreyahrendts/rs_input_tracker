#### Track Rightscale input versions

Setup

1. Create schema in mysql
2. Set environment variables on host server
   1. PRODUCT_NAME
   2. ENVIRONMENT
   3. REGION <== `AWS Region`
3. Setup the following parameters in EC2 SSM Store, using PREFIX `[ENVIRONMENT]_INPUTTRACKER_`
   1. DB_HOST
   2. DB_NAME
   3. DB_USERNAME
   4. DB_PASSWORD
   5. EMAIL
   6. PASSWORD
   7. RS_ACCOUNTS
3. `bundle install`
4. `rackup`
5. `curl URL_TO_APP/update` (this will perform the initial pull from all accounts in rightscale.yml)
6. perform updates on a schedule using same route 👆🏿
7. ????
8. profit
