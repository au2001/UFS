# Unlimited File System (UFS)

The idea of this project comes from [Unlimited Disk Storage (UDS)](https://github.com/stewartmcgown/uds). It uses [OSXFUSE](https://github.com/osxfuse/osxfuse).

---

# Introduction

UFS is a Mac application which mounts an Unlimited File System. It is backed up by Google Drive.\
UFS exploits the fact that Google Docs, especially Sheets, don't take up any space from your quota (from [here](https://support.google.com/drive/answer/6374270?hl=en)).

This does not seem to be explicitly forbidden by Google's terms, but it is still not recommended to use at large scale.\
UFS and its developers can not be held liable for any file loss or action taken by Google.

---

# Installation

1. [Install OSXFUSE](https://github.com/osxfuse/osxfuse/releases).
2. [Download UFS](https://github.com/au2001/UFS/releases).
3. Launch the UFS application you just downloaded.
4. The first time you open the application, you wil be asked to login to your Google account.
5. Once logged in, a new drive will appear in your Volumes.
6. Each time you want to access your drive, launch the UFS application. You can add it to your Login Items on macOS.
7. You can create, edit, delete, move and transfer files just as on your regular hard drive.

---

# How it works

UFS acts just like a [NAS](https://en.wikipedia.org/wiki/Network-attached_storage), or a bit like an external drive/USB key.\
When you create or copy files in this drive, they are converted to text using a Base64-like algorithm.\
The generated text is then compressed and optionnally encrypted before uploading, to secure your data.\
It is then written inside a Google Sheets document which is uploaded to your Google Drive.

---

# Restrictions & Speed limits

> Soon™

---

# Upcomming features

- Automatic compression of your files before uploading
- Automatic encryption of files on your Google Drive
- Obfuscation of directory structure and file names
- iOS app to access unlimited storage on-the-go

---

# FAQ

### Can I access my files from another computer/from my phone?

Although your files are stored on your Google Drive, they are in a special format that doesn't allow you to read or download them directly.\
To access your files from a different computer running macOS, you can install this application and login with the same Google Account you used to store them.

On a phone or on computer which do not run macOS, you can not currently access your files.\
This might change, as applications for other platforms are on the way.

### Can I share files with other people/collaborate on documents?

You can share your Google account and files will automatically synchronize between you.\
If you have encryption enabled, you will have to share your encryption keys for the files to be readable.

Beware that sharing your Google account also allows access to emails, all Google Drive files, and many other.\
Per-file sharing is currently not supported and is not planned to be added in the future.

### I found a bug, how can I report it?/I have an idea for a new feature, where can I share it?

Report bugs and suggest new features through [GitHub Issues](https://github.com/au2001/UFS/issues).

### I am a developer, can I help?

Of course, help would be greately appreciated.\
You can create a pull request and implement features in the `Upcomming features` section.\
You can also open an issue/pull request if you wish to develop something new in the app.