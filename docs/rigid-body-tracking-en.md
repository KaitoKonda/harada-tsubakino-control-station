# Rigid Body Tracking

This page provides detailed instructions to create rigid bodies in Motive, and covers other useful features associated with rigid body assets.

In Motive, Rigid Body assets are used for tracking rigid, unmalleable, objects. A set of markers is securely attached to tracked objects, and respective placement information is used to identify the object and report 6 Degree of Freedom (6DoF) data. Thus, it's important that the distances between placed markers stay the same throughout the range of motion. Either passive retro-reflective markers or active LED markers can be used to define and track a Rigid Body.&#x20;

## Rigid Body Marker Placement

A Rigid Body in Motive is a collection of three or more markers on an object that are interconnected to each other with an assumption that the tracked object is unmalleable. More specifically, Motive assumes the spatial relationship among the attached markers remains unchanged and the marker-to-marker distance does not deviate beyond the allowable *deflection* tolerance defined under the corresponding Rigid Body properties. Otherwise, involved markers may become [unlabeled](https://docs.optitrack.com/motive/data-recording.md). Cover any reflective surfaces on the Rigid Body with non-reflective materials and attach the markers on the exterior of the Rigid Body where cameras can easily capture them.

{% hint style="info" %}
**Tip:** If you wish to get more accurate 3D orientation data (pitch, roll, and yaw) of a Rigid Body, it is beneficial to spread markers as far as you can within the same Rigid Body. By placing the markers this way, any slight deviation in the orientation will be reflected from small changes in the position.
{% endhint %}

![Left: Retroreflective markers placed on a quadrocopter. Right: The corresponding rigid body defined in Motive.](https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/2XRSavrpNyQdXZtmIiEn/Quadrocopter%20Live%20and%20MoCap.png)

### Number of Markers

In a 3D space, a minimum of three coordinates are required for defining a plane using vector relationships. Likewise, at least three markers are required to define a Rigid Body in Motive. Whenever possible, it is best to use 4 or more markers to create a Rigid Body. Additional markers provide more 3D coordinates for computing positions and orientations of a rigid body, making overall tracking more stable and less vulnerable to marker occlusions. When any of markers are occluded, Motive can reference other visible markers to solve for the missing data and compute the position and orientation of the rigid body.

However, placing too many markers on one Rigid Body is not recommended. When too many markers are placed in close vicinity, markers may overlap on the camera view, and Motive may not resolve individual reflections. This can increase the likelihood of label-swaps during capture. Securely place a sufficient number of markers (usually less than 10), just enough to cover the main frame of the Rigid Body.

{% hint style="warning" %}
Tip: The recommended number of markers per Rigid Body is **4 \~ 12 markers**.&#x20;

You may encounter limits if using an excessive number of markers, or experience system performance issues when using the refine tool on such an asset. &#x20;
{% endhint %}

### Asymmetrical Marker Placements

Within a Rigid Body asset, the markers should be placed asymmetrically because this provides a clear distinction of orientations. Avoid placing the markers in symmetrical shapes such as squares, isosceles, or equilateral triangles. Symmetrical arrangements make asset identification difficult and may cause the Rigid Body assets to *flip* during capture.

### Unique Marker Placements

When tracking multiple objects using passive markers, it is beneficial to create **unique** Rigid Body assets in Motive. Specifically, you need to place retroreflective markers in a distinctive arrangement between each object, which will allow Motive to more clearly identify the markers on each Rigid Body throughout capture. In other words, their unique, non-congruent, arrangements work as distinctive identification flags among multiple assets in Motive. This not only reduces processing loads for the Rigid Body solver, but it also improves the tracking stability. Not having unique Rigid Bodies could lead to labeling errors especially when tracking several assets with similar size and shape.

![](https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/44J5GxH7LuHpVJgZaeZm/UniqueRBs.gif)

{% hint style="info" %}
**Note for Active Marker Users**

If you are using [OptiTrack active markers](https://docs.optitrack.com/active-classic/active-marker-tracking.md) for tracking multiple Rigid Bodies, it is not required to have unique marker placements. Through the active labeling protocol, active markers can be labeled individually, and multiple rigid bodies can be distinguished through uniquely assigned marker labels. Please read through [Active Marker Tracking](https://docs.optitrack.com/active-classic/active-marker-tracking.md) page for more information.
{% endhint %}

#### **What Makes Rigid Bodies Unique?**

The key idea of creating unique Rigid Body is to **avoid geometrical congruency** within multiple Rigid Bodies in Motive.

* **Unique Marker Arrangement.** Each Rigid Body must have a unique, non-congruent, marker placement creating a unique shape when the markers are interconnected.
* **Unique Marker-to-Marker Distances.** When tracking several objects, introducing unique shapes could be difficult. Another solution is to vary Marker-to-marker distances. This will create similar shapes with varying sizes and make them distinctive from the others.
* **Unique Marker Counts** Adding extra markers is another method of introducing uniqueness. Extra markers will not only make the Rigid Bodies more distinctive, but they will also provide more options for varying the arrangements to avoid the congruency.

#### **What Happens When Rigid Bodies Are Not Unique?**

Having multiple non-unique Rigid Bodies may lead to mislabeling errors. However, in Motive, non-unique Rigid Bodies can also be tracked fairly well as long as the non-unique Rigid Bodies are continuously tracked throughout capture. Motive can refer to the trajectory history to identify and associate corresponding Rigid Bodies within different frames.&#x20;

Even though it is possible to track non-unique Rigid Bodies, we strongly recommend making each asset unique. Tracking of multiple congruent Rigid Bodies could be lost during capture either by occlusion or by stepping outside of the capture volume. Also, when two non-unique Rigid Bodies are positioned in vicinity and overlap in the scene, their marker labels may get swapped. If this happens, additional efforts are required to [correct the labels](https://docs.optitrack.com/motive/labeling.md) in post-processing of the data.

#### **Tracking Multiple Rigid Bodies**&#x20;

Depending on the object, there could be limitations on marker placements and number of variations of unique placements that could be achieved. The following list provides sample methods for varying unique arrangements when tracking multiple Rigid Bodies.

* **Create Distinctive 2D Arrangements.** Use distinctive, non-congruent, marker arrangements as the starting point for producing multiple variations, as shown in the examples above.
* **Vary marker height.** Use marker bases or posts of different heights to introduce variations in elevation to create additional unique arrangements.
* **Vary Maximum Marker to Marker Distance.** Increase or decrease the overall size of the marker arrangements.
* **Add Two (or more) Markers** Lastly, if an additional variation is needed, add extra markers. We recommended adding at least two extra markers in case any become occluded.

## Creating a Rigid Body

In creating a Rigid Body asset, a set of markers attached to a rigid object are grouped and auto-labeled as a Rigid Body. This Rigid Body definition can be used in multiple takes to continuously auto-label the same asset markers. Motive recognizes the unique spatial relationship in the marker arrangement and automatically labels each marker to track the Rigid Body.&#x20;

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/I5MfSJveX05ySdJo9v7t/image.png" alt="" width="563"><figcaption><p>Builder Pane:  Create a Rigid Body.</p></figcaption></figure>

### Steps to Create a Rigid Body

**Step 1:**  Select all associated Rigid Body markers in the [3D viewport](https://docs.optitrack.com/motive-ui-panes/viewport.md#perspective-view).

**Step 2:**  On the [Builder pane](https://docs.optitrack.com/motive-ui-panes/builder-pane.md), confirm that the selected markers match those on the object you want to define as the Rigid Body.&#x20;

**Step 3:**  Click *Create* to define a Rigid Body asset from the selected markers.

You can also create a Rigid Body by doing the following actions while the markers are selected:

* **Perspective View (3D viewport):**  Right-click the selection in the perspective view to access the context menu. Under the *Markers* section, click *Create Rigid Body*.

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/D5Wwo3Ibw3QudtnmN4eN/image.png" alt="" width="265"><figcaption><p>Creating a Rigid Body from selected markers (8) <br>using the right-click context menu.</p></figcaption></figure>

* **Assets pane:**  Click the add <img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/HPussl8BIcd3ljt5PmLQ/Add%20Button%20-%20Active.png" alt="" data-size="line"> button at the bottom of the [Assets pane](https://docs.optitrack.com/motive-ui-panes/assets-pane.md).

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/RBuYL9YZyKWgNawhVv2y/image.png" alt="" width="308"><figcaption><p>Creating a Rigid Body from the Assets pane. </p></figcaption></figure>

* **Hotkey:**  While the markers are selected, use the *create Rigid Body* hotkey (Default: Ctrl +T).

**Step 4:**  Once the Rigid Body asset is created, the markers will be colored (labeled) and interconnected to each other. The newly created Rigid Body will be listed under the [Assets pane](https://docs.optitrack.com/motive-ui-panes/assets-pane.md).

{% hint style="info" %}
Motive can detect and pair a rigid body to its associated IMU. See the [IMU Sensor Fusion](https://docs.optitrack.com/motive/imu-sensor-fusion.md) page for more details. &#x20;
{% endhint %}

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/jGgzRf9frCxSpoCFomas/Rigid%20Body%20in%20the%20Viewport%20-%20nothing%20selected.png" alt=""><figcaption><p>Rigid Body in the 3D Viewport.</p></figcaption></figure>

{% hint style="info" %}
**Defining Assets in Edit mode:**

If Rigid Bodies are created in Edit mode, the corresponding *Take* needs to be [auto-labeled](https://docs.optitrack.com/motive/data-recording/data-types.md). The Rigid Body markers will be labeled using the Rigid Body asset and positions and orientations will be computed for each frame. If the 3D data have not been labeled after edits on the recorded data, the asset may not be tracked.
{% endhint %}

<img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/KMfnYqqAP4lcAznY7zZ6/Builder%20Pane%20-%20Create%20RB%20selected.png" alt="Creating a Rigid Body" width="563">

### Rigid Body Properties

Rigid Body properties define the specific configurations of Rigid Body assets and how they are tracked and displayed in Motive. For more information on each property, read the [Properties: Rigid Body](https://docs.optitrack.com/motive-ui-panes/properties-pane/properties-pane-rigid-body.md) page.

#### **Default Properties**

Default properties are applied to any newly created asset, such as minimum markers to boot or continue, asset scale, and asset name and color. Default properties are configured under the Assets section in the [Application Settings](https://docs.optitrack.com/motive-ui-panes/settings/settings-assets.md) panel. Click the <img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/9uaOX05dDg5W6lQzSW1l/Settings%20button.png" alt="" data-size="line"> button to open.&#x20;

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/hcazc0k3ROtOkQ1d6YFj/image.png" alt="" width="563"><figcaption><p>Asset and Rigid Body default configuration settings.</p></figcaption></figure>

#### **Modifying Properties**

Properties for existing Rigid Body assets can be changed from the [Properties pane](https://docs.optitrack.com/motive-ui-panes/properties-pane.md).

<img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/sem5z1GjnU2twi8lVoBd/Properties%20-%20Rigid%20Body%20standard.png" alt="Properties of a selected Rigid Body under the Properties pane." width="563">

### Add or Remove Markers

There are multiple ways to add or remove markers on a Rigid Body.&#x20;

* From the [Assets pane](https://docs.optitrack.com/motive-ui-panes/assets-pane.md), select the Rigid Body that needs markers added or removed.
* In the 3D [Viewport](https://docs.optitrack.com/motive-ui-panes/viewport.md), select the marker(s) to be added or removed. &#x20;
* From the [Constraints Pane](https://docs.optitrack.com/motive-ui-panes/constraints-pane.md): &#x20;
  * At the bottom of the pane, click <img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/Web6GKgHAetmYqXYvRQG/Add%20Button%20-%20Active.png" alt="" data-size="line"> to add or <img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/0Ino9AZejOcO01tH89Z1/Remove%20button%20-%20active.png" alt="" data-size="line"> to remove the selected marker(s).
* From the [Builder pane](https://docs.optitrack.com/motive-ui-panes/builder-pane.md):
  * Select the Modify tab.
  * In the Marker Constraints section, click <img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/Web6GKgHAetmYqXYvRQG/Add%20Button%20-%20Active.png" alt="" data-size="line"> to add or <img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/0Ino9AZejOcO01tH89Z1/Remove%20button%20-%20active.png" alt="" data-size="line"> to remove the selected marker(s).

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/QPiaag9RIYd81LFxSbEc/Builder%20Pane%20-%20Modify%20RB%20Marker%20Restraints%20highlighted.png" alt="" width="247"><figcaption><p>Add or Remove Marker Constraints from the Builder Pane.</p></figcaption></figure>

## Tracking a Rigid Body

The pivot point or bone of a Rigid Body is used to define both its position and orientation. The default position of the bone for a newly created rigid body is at its geometric center and its orientation axis will align with the global coordinate axis. To view the pivot point in the 3D viewport, enable the *Bone* setting in the Visuals section of the selected Rigid Body in the [Properties pane](https://docs.optitrack.com/motive-ui-panes/properties-pane/properties-pane-rigid-body.md).

<img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/eWzfBNrSlmbBzE7XsLTY/Info%20Pane%20-%20Rigid%20Body.png" alt="Rigid Body real-time information shown in the Info pane. 
Position is in respect to the global origin, and orientation is in 
respect to the initial orientation when the Rigid Body was created." width="375">

### Real-time Information

Position and orientation of a tracked Rigid Body can be monitored in real-time from the [Info pane](https://docs.optitrack.com/motive-ui-panes/info-pane.md). Select a Rigid Body in Motive, open the Info pane by clicking the <img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/XfgpYs3puAKvlvqW58TK/Info%20Pane%20button.png" alt="" data-size="line"> button on the toolbar. Click the <img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/ztVvhMfPfrlmmf5UOI4A/Motive%20Context%20Menu.png" alt="" data-size="line"> button in the top right corner and select Rigid Bodies from the menu to view respective real-time tracking data of the selected Rigid Body.

## Adjusting a Rigid Body Pivot Point

The location of a pivot point can be adjusted by assigning it to a marker or by translating along the Rigid Body axis (x, y, z). For the most accurate pivot point location, attach a marker at the desired pivot location, set the pivot point to the marker, and apply the translation for precise adjustments.&#x20;

### Post-Processing Edit Modes

**Edit Mode** is used for playback of captured *Take* files. In this mode, you can playback and stream recorded data and complete post-processing tasks. The Cameras View displays the recorded 2D data while the 3D Viewport represents either recorded or real-time processed data, as described below.

There are two modes for editing:

* **Edit:** Playback in standard Edit mode displays and streams the processed 3D data saved in the recorded *Take*. Changes made to settings and assets are not reflected in the Viewport until the *Take* is [reprocessed](https://docs.optitrack.com/motive/reconstruction-and-2d-mode.md#applying-changes-to-3d-data).&#x20;
* **Edit 2D:** Playback in Edit 2D mode performs a live reconstruction of the 3D data, immediately reflecting changes made to settings or assets. These changes are displayed in real-time but are not saved into the recording until the *Take* is [reprocessed](https://docs.optitrack.com/motive/reconstruction-and-2d-mode.md#applying-changes-to-3d-data) and saved. To playback in 2D mode, click the Edit button and select *Edit 2D*. &#x20;

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/xynX3M5XEiEPQqA9gWoX/Live%20or%20Edit%20mode%20-%20switch%20to%202D.png" alt="" width="200"><figcaption><p>Click Edit to select the Edit mode.</p></figcaption></figure>

{% hint style="info" %}
Regardless of the selected Edit mode, you must reprocess the *Take* to create new 3D data based on the modifications made.&#x20;
{% endhint %}

### Default Orientation

By default, the orientation axis of a Rigid Body is aligned with the global axis when the Rigid Body is first created. Once it's created, its orientation can be adjusted, either by editing the Rigid Body orientation through the [Builder pane](https://docs.optitrack.com/motive-ui-panes/builder-pane.md) or by using the GIZMO tools.

Several tools are available on the Builder pane to align Rigid Bodies. Click <img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/ds2ySP0LHviqIJNlRPrT/Builder%20Pane%20button.png" alt="" data-size="line"> to open the builder pane then click on the Modify tab. Select a Rigid Body in the 3D Viewport to see the Rigid Body tools.&#x20;

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/Xn2sR6TjsDWWAHpazyaO/Builder%20Pane%20-%20Modify%20RB%20unexpanded.png" alt="" width="305"><figcaption><p>The Builder Pane / Modify Tab.<br>Options to modify a Rigid Body.</p></figcaption></figure>

### Location:  Translate Pivot Point

Use the *Location* tool to enter the amount of translation (in mm) to apply along the (x, y, z) coordinates then click *Apply*. Clicking *Apply* again will add to the existing translation and can be used to fine-tune the adjustment of the bone.&#x20;

Click *Clear* to reset the fields to 0mm.

*Reset* will position the pivot point at the geometric center of the Rigid Body according to its marker positions.

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/cqOBmCYDb3PwAawAII11/Builder%20Pane%20-%20Modify%20RB%20-%20Location%20settings.png" alt=""><figcaption><p>The Builder Pane / Modify Tab.<br>Translate tools for Rigid Bodies.</p></figcaption></figure>

### Orientation:  Rotate Pivot Point

Use this tool to apply rotation to the local coordinate system of a selected Rigid Body. You can also reset the orientation to re-align the Rigid Body coordinate axis and the global axis. When resetting the orientation, the Rigid Body must be tracked in the scene.

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/IDJEdvJLB40wNFPh6sN2/Builder%20Pane%20-%20Modify%20RB%20Orientation%20expanded.png" alt=""><figcaption><p>The Builder Pane / Modify Tab.<br>Rotate tools for Rigid Bodies.</p></figcaption></figure>

### Reset Pivot Point:  Context Menu

In addition to the Reset buttons on the Builder pane, you can right-click a selected rigid body to open the Asset(s) context menu. Select *Bones (#) --> Reset Location.*&#x20;

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/T6mCAbdrVdLVuiKiDUVA/Rigid%20Body%20Context%20-%20Reset%20Bone%20Location.png" alt="" width="423"><figcaption><p>Asset(s) Context Menu for a Rigid Body - Bones > Reset Location.</p></figcaption></figure>

### Align to Geometry

The Align to Geometry feature provides an option to align the pivot of a rigid body to a geometry offset. Motive includes several standard geometric objects that can be used, as well as the ability to import custom objects created in other applications. This allows for consistency between Motive and external rendering programs such as Unreal Engine and Unity.&#x20;

To use this feature, select the rigid body from the Assets pane. In the Properties pane, click the <img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/Q5cIiktntTIjS4kXrpxA/Motive%20Context%20Menu.png" alt="" data-size="line"> button and select *Show Advanced* if it is not already selected. &#x20;

Scroll to the *Visuals* section of the asset's properties. Under *Geometry*, select the object type from the list.&#x20;

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/N18dMP96AYChhHZyvAGq/Rigid%20Body%20Align%20to%20Geometry.png" alt="" width="249"><figcaption><p>Rigid Body Advanced Properties:  Geometry.</p></figcaption></figure>

To import your own object, select *Custom Model*. This will open the *Attached Geometry* field. Click on the file folder icon to select the .obj, .fbx, or .stl file to import into Motive. &#x20;

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/Lmdpv3AAGlyxJYSko06c/Asset%20Properties%20-%20Attach%20custom%20geometry.png" alt="" width="287"><figcaption><p>Select custom geometry Model. </p></figcaption></figure>

### Align to Camera

To align an asset to a specific camera, select both the asset and the camera in the 3D ViewPort. Click *Camera* in the *Align to...* field in the Modify tab.

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/FStEWWqAoHJgXBVEBwAv/Builder%20Pane%20-%20Modify%20RB%20Align%20to%20Object.png" alt="" width="302"><figcaption></figcaption></figure>

### Align to Rigid Body

To align an asset to an existing Rigid Body, you must be in 2D edit mode. Click the Edit button at the bottom left and select *EDIT 2D* from the menu.&#x20;

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/GRDWUeFeDMgOUYI2rtQj/Live%20or%20Edit%20mode%20-%20switch%20to%202D.png" alt="" width="200"><figcaption><p>Switch from 3D to 2D edit mode.</p></figcaption></figure>

### Spherical Bone Placement

This feature is useful when tracking a spherical object (e.g., a ball). Motive will assume all of the markers on the selected Rigid Body are placed on the surface of a spherical object and will calculate and re-position the pivot point accordingly. Simply select a Rigid Body in Motive, open the Builder pane to edit Rigid Body definitions, and then click *Apply* to place the pivot point at the center of the spherical object.

### Refine

The Rigid Body refinement tool improves the accuracy of the Rigid Body calculation in Motive. When a Rigid Body asset is initially created, Motive references only a single frame to define it. The Rigid Body refinement tool allows Motive to collect additional samples, achieving more accurate tracking results by improving the calculation of expected marker locations of the Rigid Body as well as the position and orientation of the Rigid Body itself.

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/A7TiKvSAqaTeYSDg0jaR/Builder%20Pane%20-%20Refine%20RB.png" alt=""><figcaption><p>Refine a Rigid Body from the Builder pane Modify tab.</p></figcaption></figure>

#### **Steps**

1. From the [View](https://docs.optitrack.com/motive-ui-panes/toolbar-command-bar.md#view) menu, open the [Builder pane](https://docs.optitrack.com/motive-ui-panes/builder-pane.md), or click the <img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/su7JT8zGWiWCjTVVLTn1/Builder%20Pane%20button.png" alt="" data-size="line"> button on the toolbar.
2. Click the *Modify* tab.
3. Select the Rigid Body to be refined in the Asset pane.&#x20;
4. To refine the asset in [Live mode](https://docs.optitrack.com/motive-ui-panes/control-deck.md#live-and-edit-mode), hold the selected Rigid Body at the center of the capture volume so as many cameras as possible can clearly capture its markers.
   1. In the **Refine** section of the Modify tab of the Builder pane, click *Start...*
   2. Slowly rotate the Rigid Body to collect samples at different orientations until the progress bar is full.
5. You can also refine the asset in Edit mode. Motive will automatically replay the current take file to complete the refinement process.&#x20;

<div><figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/xxhlntQFkUnWPhTEbTMK/Refine%20RB%20-%20in%20progress.png" alt=""><figcaption><p>Rigid Body Refinement in Progress.</p></figcaption></figure> <figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/EBC77VzAuI2OJ4qTSCrV/Refine%20RB%20-%20results.png" alt=""><figcaption><p>Rigid Body Refinement Results.</p></figcaption></figure></div>

### The Gizmo Tools

The [gizmo tools](https://docs.optitrack.com/motive/assets/gizmo-tool-translate-rotate-and-scale.md) under the mouse options button in the perspective view of the 3D Viewport are another option to easily modify the position and orientation of Rigid Body pivot points.&#x20;

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/9VM9JB4YC3t7Dd4z7fo5/image.png" alt=""><figcaption><p>Gizmo tool menu in <br>the perspective viewport.</p></figcaption></figure>

* **Select Tool (Hotkey: Q):**  The Default option. Used for selecting objects in the Viewport. Return to this mode when you are done using the Gizmo tools.&#x20;
* **Translate Tool (Hotkey: W):**  Translate tool for moving the Rigid Body pivot point.
* **Rotate Tool (Hotkey: E):**  Rotate tool for reorienting the Rigid Body coordinate axis.
* **Scale Tool (Hotkey: R):**  Scale tool for resizing the Rigid Body pivot point.

Please see the [Gizmo tools](https://docs.optitrack.com/motive/assets/gizmo-tool-translate-rotate-and-scale.md) page for detailed information.

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/Ln2FTwPQvn0zVrXvHy55/image.png" alt=""><figcaption><p>Gizmo Translate Tool in the 3D Viewport.</p></figcaption></figure>

## Rigid Body Tracking Data Output

Rigid Body tracking data can be exported or streamed to client applications in real-time:

* Captured 6 DoF Rigid Body data can be exported into CSV, or FBX files. Please read the [Data Export](https://docs.optitrack.com/motive/data-export.md) page for more details.
* You can also use one of the streaming plugins or use NatNet client applications to receive tracking data in real-time. See: [NatNet SDK](https://docs.optitrack.com/developer-tools/natnet-sdk/natnet-4.5.md).

## Additional Features

### Hide Markers for Disabled Assets

You can disable assets and hide their associated markers once you are finished labeling and editing them to better focus on the remaining unedited assets.&#x20;

To disable an asset, uncheck the <img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/fgr1DuNaCWCw2oFaYF5c/Assets%20Pane%20-%20Enable%20Asset.png" alt="" data-size="line"> box to the left of the asset name in the Asset pane.&#x20;

**To Hide Markers:** &#x20;

* Click the <img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/V9aHiWejQZj7zxl2qQGu/Viewport%20Visual%20Options%20button.png" alt="" data-size="line"> button in the 3D Viewport.
* Select Markers > Hide for Disabled Assets.&#x20;

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/B8ah8TmXNVsplgxemwyx/Visual%20Options%20-%20Rigid%20Body%20menu.png" alt=""><figcaption><p>Marker Options from the Visuals menu in the 3D Viewport.</p></figcaption></figure>

### Export Asset Definitions

Assets can be exported into the Motive user profile (.MOTIVE) file if they need to be re-imported. The [user profile](https://docs.optitrack.com/motive/pages/KhJrv0dZJx3yYwdrmwCW#motive-user-profile-.motive) is a text-readable file that contains various configuration settings in Motive. This can include asset definitions.

When an asset definition is exported to a user profile, Motive stores marker arrangements calibrated to the asset, which allows the asset to be imported into different takes without being rebuilt each time in Motive.&#x20;

Profile files specifically store the spatial relationship of each marker. Only the identical marker arrangements will be recognized and defined with the imported asset.

To export all of the assets in Live or in the current *TAKE* file, go to the *File* menu → *Export Assets*.&#x20;

You can also select *Export Profile* from the *File menu* to export other software settings, in addition to the assets.

![Exporting Assets into the User Profile.](https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/tNiMFEJRqv4BUI7tGCxK/image.png) ![Exporting user profile that includes assets. This dialogue window is from the Export Profile As... option.](https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/LhoMbHPC2gJQJcEhb9OA/image%20\(453\).png)
