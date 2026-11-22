# dev: public demo endpoint, scales to zero, small cap, disposable.
project_id          = "zdml-demo-dev"
public              = true
min_instances       = 0
max_instances       = 2 # enough for the 20 rps demo load; the cap is the cost guard
deletion_protection = false
# The prod deployer pulls promoted images from here.
registry_readers = ["serviceAccount:deployer@zdml-demo-prod.iam.gserviceaccount.com"]
