
## GUIGNA: the GUI of Guigna is Not by Apple  :)

Guigna* is the prototype of a GUI supporting Homebrew, MacPorts, Fink and pkgsrc
at the same time.


![screenshot](https://raw.github.com/gui-dos/Guigna/master/guigna-screenshot.png)


## Design and ideas

Guigna tries to abstract several package managers by creating generalized classes
(GSystem and GPackage) while keeping a minimalist approach and using screen
scraping. The original implementations in Objective-C and MacRuby/RubyMotion are
being ported to Swift.

Guigna doesn't hide the complexity of compiling open source software: it launches
the shell commands in a Terminal window you can monitor and interrupt. When
administration privilege or another input are required, the answer to the
prompt can be typed directly in the Terminal brought to the foreground thanks
to the Scripting Bridge. 

When multiple package managers are detected, their sandboxes are hidden by appending
`_off` to their prefix before the compilation phase. An on-line mode, however,
allows to get the details about the packages by scraping directly their original
repositories.


## Feedback

Guigna is at a very early stage of development and it is tested only for the
latest versions of macOS, Xcode and Swift betas. Some preliminary builds are
available from [Dropbox](https://www.dropbox.com/sh/y1wpmndu1vn7pqp/AABCqKxUa-_Soqf57EVzhYILa?dl=0).

Some advice and warnings:

- Add the system prefixes (`/opt/local`, `/usr/local`, `/sw`) and their
  hidden versions (with a `_off` suffix) to the Private section of the
  Spotlight preference panel, since they are renamed continuously.
  No other modifications are made to the system: simply delete
  `~/Library/Application Support/Guigna` and execute 
  `defaults delete name.soranzio.guido.Guigna` for a fresh restart.
- In systems other than MacPorts and Homebrew many commands don't
  work since they are still sketched mock-ups.
- `Stop` is not implemented yet. Forcing quitting and restarting Guigna
  should offer to unhide the detected prefixes. Remember that, in comparison
  to other traditional GUIs, Guigna is scripting the Terminal and you can
  always check the tasks which are executing in the shell.


```
    GSource is a collection of GItems
       .                         .
      /_\                       /_\
       |                         |             status: available
       |                         |                     uptodate
                                                       outdated
    GSystem                  GPackages                 inactive


    The following GSystem methods execute the corresponding command,
    update the 'items' array and return a copy:

    - list
    - installed
    - outdated
    - inactive

    The following methods build and return the corresponding commands
    as strings:

    -   installCmd(pkg)
    - uninstallCmd(pkg)
    -   upgradeCmd(pkg)
    
    The following methods execute specific commands and return the output:
   
    -     home(item)   URL of the original website
    -      log(item)   URL of the page listing the versions/commits
    -     info(item)   output of the 'info' command
    -     deps(item)   list of the dependencies/requirements
    -      cat(item)   portfile, formula, spec or makefile
    - contents(item)   list of installed files


    Other GSystem methods and properties:

    - index     dictionary of the system's items, having
                'name-system' as keys: it is used for a fast
                access when determining new and updated items

    - [name]    accessor to the indexed package carrying that name

    - prefix    /opt/local, /usr/local, /sw, /usr/pkg, ...

    - cmd       prefix + /bin/port | bin/brew | /bin/fink | ...

    - agent     passed by appDelegate and implementing the methods:
                - nodesForURL:XPath:
                - outputForCommand:
                - appDelegate (it gives access to GuignaAppDelegate)

    - outputFor shortcut for calling agent's outputForCommand: method,
                passing a format and a va_list of args
                

    GPackage properties:

    - system     weak reference to its GSystem (GSource)
      (source)

    - installed  installed version (string or nil)

    - mark       enum: install, uninstall, upgrade, fetch, ...

    - options    available variants/options/flags, joined by space

    - marked     variants/options/flags marked by the user for committing
      Options

    - *Cmd       shortcuts to self.system.*Cmd(pkg), passing itself as argument
      
    Inactive packages are not indexed and are inserted also directly in
    the appDelegate's allPackages array.

```
--

\* The [Kodkod](http://en.wikipedia.org/wiki/Kodkod) (_Leopardus guigna_), also
called **guiña**, is the smallest cat in the Americas.

![icon](http://4.bp.blogspot.com/-tDKNTW-rJLU/UmU7Iro9vRI/AAAAAAAAAQQ/GR_SpJc1s6o/s1600/kodkod+(1).jpg)

