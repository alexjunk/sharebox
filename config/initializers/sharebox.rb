MAIN = YAML.load_file("#{Rails.root}/config/config.yml")["main"]
FOLDERS_MSG = YAML.load_file("#{Rails.root}/config/config.yml")["folders_msg"]
USERS_MSG = YAML.load_file("#{Rails.root}/config/config.yml")["users_msg"]
ASSETS_MSG = YAML.load_file("#{Rails.root}/config/config.yml")["assets_msg"]
POLLS_MSG = YAML.load_file("#{Rails.root}/config/config.yml")["polls_msg"]
SATISFACTIONS_MSG = YAML.load_file("#{Rails.root}/config/config.yml")["satisfactions_msg"]
SHARED_FOLDERS_MSG = YAML.load_file("#{Rails.root}/config/config.yml")["shared_folders_msg"]