# IOS Bugs

## Login to use app

We should make the app "usable" without signing into vikunja.

This means, the functionality of the app will be heavily degraded, but we should replace any content which would come from Vikunja with a "sign in to Vikunja" prompt (which opens the "sign in" screen)

eg: "Choose project" could open the "choose" picker, but the two options should be "auto-match" and "sign in to vikunjka to choose a project"

Dry run / Apply should have a "sign in to vikunja" notice, and dry run/apply be visually obviously disabled 

## Sign Out should be hidden

We should "hide" the "Sign Out" button so it's not easy to accidentally sign out of Vikunja.

A "Cog" menu for "settings" would do it.
or "hamburger" menu.

In that menu we could have the "sign in" and "sign out", plus have room for anything else in future.

## Feedback

a "Feedback" option somewhere would be good (I'll work out the email address later), it can just open an email address.

## Github 

A link to the github repo would be good.

## Styling

I'm ok with the app being a bit "boring" looking, thats fine.

## Sync details output

Most users won't want the logs at all.

We should have a "Sync Complete" type message, on the "everything went fine" path.

We should probably not have a "Dry Run" button at all, for most users?

If there are no conflicts, we shouldn't tell the user about the conflict logs - only surface them when there's something to surface (and probably have a "request support" button which attaches the sync log (with privacy redactions if needed) to an email for support)

When a sync _does_ fail, maybe "Sync completed with errors", and then let the user try to work out the problem? If we can provide a "this reminder has this problem" or "this task has this problem" output, users would prefer that.




