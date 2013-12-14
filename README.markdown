

# *Affectations/Torso*

**H. James Harkins**   
   Composed 2010, revised 2013   
   For computer, with gestural control by webcam

This repository contains the code for my composition
*Affectations/Torso*. I am publishing it as supplementary material for
an article, &ldquo;*Affectations/Torso*: A case study in future-proofing
interactive computer music through robust code design,&rdquo; appearing in
vol. 11 of *Emille*, the journal of the Korean Electro-Acoustic Music
Society.

## Code relevant to the article

### Trigger mediator

The article discusses a strategy of handling triggers from multiple
user interfaces. &ldquo;Listing 4&rdquo; is the central code example. It is, in
fact, a new version of the Mediator that is actually used in
*Torso*. The new version printed in the article is a clean,
streamlined implementation; the corresponding code in this repository
is somewhat messier. This is common in programming: the first
implementation is flawed, and the flaws can be addressed in subsequent
*refactoring*. It made more sense in the article to present the
clearest, easiest-to-understand version.

The actual implementation in the composition is found in two places:

-   `./common/common-defs.scd`, lines 730-757   
      The receiver for triggers from *vvvv*, left over from the original
    *Affectations*. The *vvvv* code is no longer used, but I left it in
    to avoid the risk of changing the structure. This is the parent
    prototype for the responders in `main_seq.scd`.

-   `./torso/main_seq.scd`, lines 50-141   
      The responder for &ldquo;segment&rdquo; (section) triggers. See especially
    `segActive`, which registers an action to take when the next section
    trigger arrives. The action is expected to be a Function, meaning
    that the strategy here is less object-oriented than that described
    in the article. The action is saved as `~segTrigAction`, which then
    becomes the central triggering location.   
      Additional code in this block handles &ldquo;event triggers,&rdquo; which occur
    within sections but don&rsquo;t advance to the next section. They are
    handled similarly, except for the additional logic to allow multiple
    event triggers with different IDs to be registered simultaneously.

### Video control

The video analyzers are found in `./torso/tracking-defs.scd`. The Pure
Data webcam patch is in `./install/Extensions/Video`.

## Installation

### Required software:

-   SuperCollider v. 3.6.6 or later. Please use the SuperCollider IDE to
    run the piece. The SCVim or gedit environments will *not*
    work. <http://supercollider.sourceforge.net/downloads/>

-   Pure Data v. 0.43.3-extended-20121002 or
    later. <http://puredata.info/downloads/pd-extended>

The piece was developed in Linux. It should run equally well in Mac
OSX. It uses UNIX shell commands to open Pure Data. These commands
will not work in Windows. Contact the composer via
<http://www.dewdrop-world.net>.

### SuperCollider extensions:

Copy `./install/Extensions` of this repository into the SuperCollider
user extension directory. If you are not sure of this location, run
the following within SuperCollider:

    Platform.userExtensionDir;

The Extensions directory in this repository contains specific versions
of two sets of [Quarks](http://doc.sccode.org/Guides/UsingQuarks.html). If you have already installed these quarks
(cruciallib and dewdrop<sub>lib</sub>), you will get &ldquo;Duplicate class&rdquo; errors
when starting SC or recompiling the class library. If this occurs, you
should uninstall cruciallib and dewdrop<sub>lib</sub>, using either `Quarks.gui`
or the following code:

    Quarks.uninstall("dewdrop_lib");
    Quarks.uninstall("cruciallib");

## Performance materials

As of this writing, no performance score exists. This lack may be
remedied at some future date. Contact the composer via
<http://www.dewdrop-world.net>.
