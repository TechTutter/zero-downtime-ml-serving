# dev: public demo endpoint, scales to zero, small cap, disposable.
project_id          = "zdml-demo-dev"
public              = true
min_instances       = 0
max_instances       = 3
deletion_protection = false
# The prod deployer pulls promoted images from here.
registry_readers = ["serviceAccount:deployer@zdml-demo-prod.iam.gserviceaccount.com"]
