# Submitting to Google Play

Read this before opening the Play Console. One question on the form decides
whether this app is allowed on the store at all, and the answer has to be
prepared rather than improvised.

## The problem

Storage Cleaner declares `MANAGE_EXTERNAL_STORAGE` — "All files access". Google
restricts it to a named list of use cases:

- File managers
- Backup and restore
- Anti-virus
- Document management
- On-device file search
- Disk and file encryption
- Device-to-device data migration

**"Cleaner" is not on that list.** Apps that describe themselves as junk
cleaners, boosters or storage optimisers are exactly the category the
restriction was written for, and a submission that leads with that word is
asking to be refused.

This is not solved by wording the description cleverly after a rejection.
Decide the framing before the first submission, because the app's store listing,
its declaration and its demo video all have to say the same thing.

## The framing

Submit under **on-device file search and file management**, because it is true:

- The app **walks the file system and shows what it finds**, with the full path,
  size and age of every file — this is the whole first half of both tools, and
  it is what the user spends most of their time in.
- It **acts only on what the user has ticked**, one row at a time, behind a
  confirmation that states the consequences.
- It **manages files rather than deleting blindly**: a cleanup moves files to a
  quarantine and can put them back for seven days.
- Everything happens **on the device**. There is no `INTERNET` permission in the
  release build at all.

What makes this defensible rather than a dodge is that scoped storage genuinely
cannot do it. The Storage Access Framework gives one folder at a time through a
picker; it cannot enumerate `%TEMP%`, `Android/data/*/cache`, or a camera roll
across every volume, which is what "show me what is filling my disk" requires.
The app already implements the picker as its fallback — see
`AndroidStorageAccessRepo.addFolder` — and it is genuinely worse, which is the
argument.

## The declaration form

**Question: why does your app need All files access?**

Draft:

> Storage Cleaner is an on-device file search and management tool. It enumerates
> the file system to show the user which files are consuming their storage —
> path, size and last-modified date for each — and lets them select individually
> which to remove or re-encode.
>
> The Storage Access Framework cannot serve this purpose. It grants access one
> user-picked directory at a time and provides no way to enumerate storage
> broadly, so the app cannot answer "what is filling my device" without All
> files access. The app implements the SAF folder picker as a fallback and
> operates in that reduced mode when All files access is refused.
>
> No file content is transmitted anywhere. The release build does not declare
> the INTERNET permission, so the app is technically incapable of network
> access. All processing is local.
>
> Files removed by the user are moved to an on-device quarantine and are
> restorable for seven days rather than deleted immediately.

**The demo video.** Required, and worth making carefully — it is read by a
reviewer who has thirty seconds. Show, in this order:

1. The permission being requested in context, after the user presses *Grant
   access* — not on launch.
2. A scan producing a list with visible paths and sizes.
3. A row being unticked, so it is obvious the user chooses.
4. The confirmation dialog, with its text readable.
5. The quarantine screen, and a batch being **restored**.

Point 5 is the one that separates this from the category Google is refusing.

## Data safety

Every answer is the easy one, and each is verifiable from the repository:

| Question | Answer |
| --- | --- |
| Does your app collect or share any user data? | **No** |
| Is all user data encrypted in transit? | N/A — no data leaves the device |
| Do you provide a way to request deletion? | N/A — nothing is collected |

Privacy policy URL: publish `PRIVACY.md` through GitHub Pages and give Play that
URL. It must stay reachable for as long as the app is listed.

If a reviewer questions "no data collected", the answer is the permission list:
the release build has no `INTERNET` permission, which can be confirmed from the
uploaded bundle without taking anyone's word for it.

## Store listing

Copy lives in `fastlane/metadata/android/`, in all three languages. Two rules
when editing it:

- **Never the words "booster", "speed up", "RAM cleaner" or "phone doctor".**
  They are the vocabulary of the category being refused, and the app does none
  of those things.
- **Say what it does not do.** No ads, no accounts, no tracking, open source.
  That is the differentiator in a category full of the opposite, and it is the
  thing a reviewer can check.

## Graphics

Both of the images Play insists on are in the tree, one set per locale, under
`fastlane/metadata/android/<locale>/images/`:

| File | Size | Play's rule |
| --- | --- | --- |
| `icon.png` | 512×512 | 32-bit PNG, square, no transparency — Play applies its own mask |
| `featureGraphic.png` | 1024×500 | no transparency, and it is cropped differently across the store, so nothing important goes near an edge |

Both are generated by `tool/brand_assets.py`, which is also what writes every
launcher icon in the project, so the icon on the listing and the icon on the
home screen cannot end up being different pictures. See `docs/BRAND.md`.

The feature graphic carries the app's name and one line, per locale, taken from
the same copy as `title.txt` and `short_description.txt` next to it. The line
shrinks to fit rather than the copy being shortened to suit the layout: Russian
runs half again as long as English and would otherwise reach into the artwork.

**Still missing: screenshots.** Play wants at least two phone screenshots, and
they have to come off a real device or an emulator — there is nothing in this
repository that can produce them, and a mock-up of a screen the app does not
draw would be a misrepresentation of the app. Take them on a phone with the
release build, in both languages if the listing is being launched in both, and
put them in `fastlane/metadata/android/<locale>/images/phoneScreenshots/`.

## Content rating and target audience

- Content rating questionnaire: no on all counts. Utility app, no user-generated
  content, no ads, no purchases.
- Target audience: 18+, or 13+. Not "all ages" — a mixed-age audience triggers
  Families policy review, which is a second review for no benefit here.

## If it is refused anyway

It may well be. The plan:

1. **F-Droid is not affected.** It has no permission review of this kind, and it
   is where the audience for an open-source cleaner already is — SD Maid SE's
   users are there. Ship there first and independently, so a Play refusal delays
   nothing. See `metadata/`.
2. **GitHub Releases are unaffected.** The workflow already publishes signed
   APKs on every tag.
3. **Appeal once, with the video.** Rejections of this permission are often
   template responses to the word "cleaner" rather than to the app; an appeal
   that shows the file listing and the restore usually gets a human.
4. **Do not ship a crippled Play build** that drops the permission and uses only
   the folder picker. It would be an app that cannot answer the question it
   exists to answer, listed under a name that promises it can.
