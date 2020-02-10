# Mautic Tag Import

Script to update tags of Mautic contacts based on CSV file.

Example of CSV file
```
email,tags
email1@example.com,"tag1,tag2"
email2@example.com,"tag2,tag 3,Another Tag"
```

*Attention: Emails must be already registered in Mautic contacts.*

## To Run

1. Create a file called `.env` with variables `MAUTIC_URL` and `MAUTIC_TOKEN`

        $ cp .env.sample .env


2. Import your CSV to Mautic to create contacts. Only already saved contacts will be updated. This script do not create contacts in Mautic.


3. Copy your CSV file to project's root path with name `contacts.csv`. The CSV must have the first line as a header with a column called `tags` and tags separated by comma, ex: `"tag1,tag2, tag 3, Another Tag"`


4. Run rake

        $ rake 