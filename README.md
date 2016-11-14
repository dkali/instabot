# instabot
Bot for instagram.
The purpose of the project is to create an Instagram application on Ruby that
- authomatically authorize itself for the user (Webdriver, OAuth 2.0) using provided <login> and <password>
- monitor for the target account activity (my friend's account) and posts likes to media he uploads (Rest client, Instagram API)
- script executes on the hourly basis (create task in OS)

Requirements:
- Ruby 2.3
- Ruby DevKit probably needs to be installed. Anyway, shame on you if you not already have him.

To resolve gem dependencies:
- gem install bundler
- bundle install