--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- This Source Code Form is subject to the terms of the Mozilla Public        --
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,  --
-- you can obtain one at http://mozilla.org/MPL/2.0/.                         --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


module Axis3d exposing
    ( Axis3d
    , x, y, z
    , through, withDirection, on
    , originPoint, direction
    , reverse, moveTo, rotateAround, translateBy, translateIn, mirrorAcross, projectOnto
    , relativeTo, placeIn, projectInto
    )

{-| An `Axis3d` represents an infinitely long straight line in 3D and is defined
by an origin point and direction. Axes have several uses, such as:

  - Rotating around the axis
  - Projecting onto the axis
  - Measuring distance along the axis from the origin point

@docs Axis3d


# Constants

@docs x, y, z


# Constructors

@docs through, withDirection, on


# Properties

@docs originPoint, direction


# Transformations

@docs reverse, moveTo, rotateAround, translateBy, translateIn, mirrorAcross, projectOnto


# Coordinate conversions

@docs relativeTo, placeIn, projectInto

-}

import Angle exposing (Angle)
import Axis2d exposing (Axis2d)
import Direction3d exposing (Direction3d)
import Geometry.Types as Types exposing (Frame3d, Plane3d, SketchPlane3d)
import Point3d exposing (Point3d)
import Quantity exposing (Quantity)
import Vector3d exposing (Vector3d)


{-| -}
type alias Axis3d units coordinates =
    Types.Axis3d units coordinates


{-| The global X axis.

    Axis3d.x
    --> Axis3d.through Point3d.origin Direction3d.x

-}
x : Axis3d units coordinates
x =
    through Point3d.origin Direction3d.x


{-| The global Y axis.

    Axis3d.y
    --> Axis3d.through Point3d.origin Direction3d.y

-}
y : Axis3d units coordinates
y =
    through Point3d.origin Direction3d.y


{-| The global Z axis.

    Axis3d.z
    --> Axis3d.through Point3d.origin Direction3d.z

-}
z : Axis3d units coordinates
z =
    through Point3d.origin Direction3d.z


{-| Construct an axis through the given point, with the given direction.

    exampleAxis =
        Axis3d.through
            (Point3d.meters 1 2 3)
            Direction3d.y

-}
through : Point3d units coordinates -> Direction3d coordinates -> Axis3d units coordinates
through givenPoint givenDirection =
    Types.Axis3d { originPoint = givenPoint, direction = givenDirection }


{-| Construct an axis with the given directoin, through the given point. Flipped
version of `through`. Having both versions allow you to do different
things with partial application:

    -- A list of axes in different directions all passing
    -- through the same origin point
    List.map (Axis3d.through point) directions

    -- A list of parallel axes (all having the same
    -- direction) through different points
    List.map (Axis3d.withDirection direction) points

-}
withDirection : Direction3d coordinates -> Point3d units coordinates -> Axis3d units coordinates
withDirection givenDirection givenPoint =
    Types.Axis3d { direction = givenDirection, originPoint = givenPoint }


{-| Construct a 3D axis lying _on_ a sketch plane by providing a 2D axis
specified in XY coordinates _within_ the sketch plane.

    axis2d =
        Axis2d.through (Point2d.meters 1 3)
            (Direction2d.fromAngle (degrees 30))

    Axis3d.on SketchPlane3d.xy axis2d
    --> Axis3d.through
    -->     (Point3d.meters 1 3 0)
    -->     (Direction3d.fromAzimuthAndElevation
    -->         (degrees 30)
    -->         (degrees 0)
    -->     )

    Axis3d.on SketchPlane3d.zx axis2d
    --> Axis3d.through
    -->     (Point3d.meters 3 0 1)
    -->     (Direction3d.fromAzimuthAndElevation
    -->         (degrees 0)
    -->         (degrees 60)
    -->     )

-}
on : SketchPlane3d units coordinates3d { defines : coordinates2d } -> Axis2d units coordinates2d -> Axis3d units coordinates3d
on sketchPlane (Types.Axis2d axis2d) =
    through (Point3d.on sketchPlane axis2d.originPoint)
        (Direction3d.on sketchPlane axis2d.direction)


{-| Get the origin point of an axis.

    Axis3d.originPoint exampleAxis
    --> Point3d.meters 1 2 3

-}
originPoint : Axis3d units coordinates -> Point3d units coordinates
originPoint (Types.Axis3d axis) =
    axis.originPoint


{-| Get the direction of an axis.

    Axis3d.direction exampleAxis
    --> Direction3d.y

-}
direction : Axis3d units coordinates -> Direction3d coordinates
direction (Types.Axis3d axis) =
    axis.direction


{-| Reverse the direction of an axis while keeping the same origin point.

    Axis3d.reverse exampleAxis
    --> Axis3d.withDirection Direction3d.negativeY
    -->     (Point3d.meters 1 2 3)

-}
reverse : Axis3d units coordinates -> Axis3d units coordinates
reverse (Types.Axis3d axis) =
    through axis.originPoint (Direction3d.reverse axis.direction)


{-| Move an axis so that it has the given origin point but unchanged direction.

    newOrigin =
        Point3d.meters 3 4 5

    Axis3d.moveTo newOrigin exampleAxis
    --> Axis3d.withDirection Direction3d.y
    -->     (Point3d.meters 3 4 5)

-}
moveTo : Point3d units coordinates -> Axis3d units coordinates -> Axis3d units coordinates
moveTo newOrigin (Types.Axis3d axis) =
    through newOrigin axis.direction


{-| Rotate an axis around another axis by a given angle. The axis to rotate
around is given first and the axis to rotate is given last.

    Axis3d.rotateAround Axis3d.z (degrees 90) exampleAxis
    --> Axis3d.withDirection Direction3d.negativeX
    -->     (Point3d.meters -2 1 3)

-}
rotateAround : Axis3d units coordinates -> Angle -> Axis3d units coordinates -> Axis3d units coordinates
rotateAround otherAxis angle =
    let
        rotatePoint =
            Point3d.rotateAround otherAxis angle

        rotateDirection =
            Direction3d.rotateAround otherAxis angle
    in
    \(Types.Axis3d axis) ->
        through (rotatePoint axis.originPoint) (rotateDirection axis.direction)


{-| Translate an axis by a given displacement. Applies the given displacement to
the axis' origin point and leaves the direction unchanged.

    displacement =
        Vector3d.fromComponents ( 3, 3, 3 )

    Axis3d.translateBy displacement exampleAxis
    --> Axis3d.withDirection Direction3d.y
    -->     (Point3d.meters 4 5 6)

-}
translateBy : Vector3d units coordinates -> Axis3d units coordinates -> Axis3d units coordinates
translateBy vector (Types.Axis3d axis) =
    through (Point3d.translateBy vector axis.originPoint) axis.direction


{-| Translate an axis in a given direction by a given distance;

    Axis3d.translateIn direction distance

is equivalent to

    Axis3d.translateBy
        (Vector3d.withLength distance direction)

-}
translateIn : Direction3d coordinates -> Quantity Float units -> Axis3d units coordinates -> Axis3d units coordinates
translateIn translationDirection distance axis =
    translateBy (Vector3d.withLength distance translationDirection) axis


{-| Mirror an axis across a plane.

    Axis3d.mirrorAcross Plane3d.xy exampleAxis
    --> Axis3d.withDirection Direction3d.y
    -->     (Point3d.meters 1 2 -3)

-}
mirrorAcross : Plane3d units coordinates -> Axis3d units coordinates -> Axis3d units coordinates
mirrorAcross plane (Types.Axis3d axis) =
    through (Point3d.mirrorAcross plane axis.originPoint)
        (Direction3d.mirrorAcross plane axis.direction)


{-| Find the [orthographic projection](https://en.wikipedia.org/wiki/Orthographic_projection)
of an axis onto a plane. If the given axis is exactly perpendicular to the given
plane, returns `Nothing`.

    Axis3d.projectOnto Plane3d.xy exampleAxis
    --> Just
    -->     (Axis3d.withDirection Direction3d.y
    -->         (Point3d.meters 1 2 0)
    -->     )

    Axis3d.projectOnto Plane3d.xy Axis3d.z
    --> Nothing

-}
projectOnto : Plane3d units coordinates -> Axis3d units coordinates -> Maybe (Axis3d units coordinates)
projectOnto plane (Types.Axis3d axis) =
    let
        projectedOrigin =
            Point3d.projectOnto plane axis.originPoint
    in
    Direction3d.projectOnto plane axis.direction
        |> Maybe.map (through projectedOrigin)


{-| Take an axis defined in global coordinates, and return it expressed in local
coordinates relative to a given reference frame.

    localFrame =
        Frame3d.atPoint
            (Point3d.meters 3 3 3)

    Axis3d.relativeTo localFrame exampleAxis
    --> Axis3d.withDirection Direction3d.y
    -->     (Point3d.meters -2 -1 0)

-}
relativeTo : Frame3d units globalCoordinates { defines : localCoordinates } -> Axis3d units globalCoordinates -> Axis3d units localCoordinates
relativeTo frame (Types.Axis3d axis) =
    through (Point3d.relativeTo frame axis.originPoint)
        (Direction3d.relativeTo frame axis.direction)


{-| Take an axis defined in local coordinates relative to a given reference
frame, and return that axis expressed in global coordinates.

    localFrame =
        Frame3d.atPoint
            (Point3d.meters 3 3 3)

    Axis3d.placeIn localFrame exampleAxis
    --> Axis3d.withDirection Direction3d.y
    -->     (Point3d.meters 4 5 6)

-}
placeIn : Frame3d units globalCoordinates { defines : localCoordinates } -> Axis3d units localCoordinates -> Axis3d units globalCoordinates
placeIn frame (Types.Axis3d axis) =
    through (Point3d.placeIn frame axis.originPoint)
        (Direction3d.placeIn frame axis.direction)


{-| Project an axis into a given sketch plane. Conceptually, this finds the
[orthographic projection](https://en.wikipedia.org/wiki/Orthographic_projection)
of the axis onto the plane and then expresses the projected axis in 2D sketch
coordinates.

This is only possible if the axis is not perpendicular to the sketch
plane; if it is perpendicular, `Nothing` is returned.

    Axis3d.projectInto SketchPlane3d.xy exampleAxis
    --> Just
    -->     (Axis2d.withDirection Direction2d.y
    -->         (Point2d.meters 1 2)
    -->     )

    -- The global Y direction is the X direction of the
    -- YZ plane:
    Axis3d.projectInto SketchPlane3d.yz exampleAxis
    --> Just
    -->     (Axis2d.withDirection Direction2d.x
    -->         (Point2d.meters 2 3)
    -->     )

    Axis3d.projectInto SketchPlane3d.xz exampleAxis
    --> Nothing

-}
projectInto : SketchPlane3d units coordinates3d { defines : coordinates2d } -> Axis3d units coordinates3d -> Maybe (Axis2d units coordinates2d)
projectInto sketchPlane (Types.Axis3d axis) =
    let
        projectedOrigin =
            Point3d.projectInto sketchPlane axis.originPoint
    in
    Direction3d.projectInto sketchPlane axis.direction
        |> Maybe.map (Axis2d.through projectedOrigin)
