# Github Process
Below are some general guidelines our team followed when using github.

## Main Goals
- Keep repository clean of unnecessary files
- Keep main branch always working and deployable
- Use clear and consistent commit messages
- Always create pull requests, never directly push to main
## Branches
The 'main' branch of the repository should always contain a working application for team members to develop off of.

If a team member wants to begin working on the application, they should create a new branch to do so.

### Branch naming:

- 'feature/feature-name'
- 'test/test-name'
- 'style/style-name'
- 'fix/fix-name'
- 'extra/extra-task-name'
### Some examples of this:

- 'feature/log-in'
- 'test/log-in-testing'
- 'fix/log-in-format'
## Commit Messages
Team members should practice making commits often when parts of the code are changed, so they are able to revert changes if needed.

Team members should also make sure commit messages are clean and simple and explain what was changed.

### Commit message format:

type(scope): short summary

- type: (what kind of change)
  - feature, test, bugfix, style, refactor
- scope: (where was the change made)
  - application.rb, user_controller.rb, etc.
### An example of this could be:

feat(login.html): Add in username and password fields

## Pull Requests
All merges with the main branch should be done through pull requests.

When a team member has finished the branch they are working on and the application successfully runs and passes all tests they should create a new pull request.

All other team members should review and comment on this pull request to determine if it should be merged into the main branch.

### Pull request format:

**type: change title (Title)**
Short summary of changes that were made and why(Description)

- Short bulleted list of changes for team members to be aware of(Changes)
### An example of this could be:

**feat: added log-in**
Log-in feature added to application with username, password, and submit button. This feature allows users already present in the system to log in by entering their username and password into the dedicated fields and then hitting the submit button. Once logged in users will be brought to the home page of the application.

- Added login.html page
- Added username and password text fields
- Added submit button
- Updated database with logged in users
