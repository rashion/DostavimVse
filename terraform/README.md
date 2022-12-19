# hse-devops-terraform
HSE DevOps Task Terraform

### App front end
![](img/app_run1.png)
![](img/app_run2.png)

### App open ports
![](img/app_port.png)

### App table
![](img/tables.png)

## Note

### If you want to connect DB:
1. Login to vm
2. Use `connect_db.sh` with `database_fqdn` as an argument

```sh
connect_db.sh ######.mdb.yandexcloud.net
```

### Do not forget to change:
- `ssh-key` in `variables.tf`
- In `main.tf`
    - `token`
    - `cloud_id`
    - `folder_id`
