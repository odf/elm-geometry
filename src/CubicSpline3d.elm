module CubicSpline3d
    exposing
        ( ArcLengthParameterized
        , CubicSpline3d
        , arcLength
        , arcLengthParameterized
        , arcLengthToParameterValue
        , bisect
        , boundingBox
        , controlPoints
        , derivative
        , derivativeMagnitude
        , derivatives
        , endDerivative
        , endPoint
        , from
        , fromControlPoints
        , fromQuadraticSpline
        , maxSecondDerivativeMagnitude
        , mirrorAcross
        , on
        , parameterValueToArcLength
        , placeIn
        , pointAlong
        , pointOn
        , pointsOn
        , projectInto
        , projectOnto
        , relativeTo
        , reverse
        , rotateAround
        , sample
        , samples
        , scaleAbout
        , secondDerivative
        , secondDerivatives
        , splitAt
        , startDerivative
        , startPoint
        , tangentAlong
        , translateBy
        , translateIn
        , underlyingSpline
        )

{-| <img src="https://ianmackenzie.github.io/elm-geometry/1.0.0/CubicSpline3d/icon.svg" alt="CubicSpline3d" width="160">

A `CubicSpline3d` is a cubic [Bézier curve](https://en.wikipedia.org/wiki/B%C3%A9zier_curve)
in 3D defined by four control points. This module contains functionality for

  - Evaluating points and derivatives along a spline
  - Scaling, rotating, translating or mirroring a spline
  - Converting a spline between local and global coordinates in different
    reference frames

@docs CubicSpline3d


# Constructors

@docs fromControlPoints, from, on, fromQuadraticSpline


# Properties

@docs controlPoints, startPoint, endPoint, startDerivative, endDerivative, boundingBox


# Evaluation

@docs pointOn, pointsOn, derivative, derivatives, sample, samples


# Transformations

@docs reverse, scaleAbout, rotateAround, translateBy, translateIn, mirrorAcross, projectOnto


# Coordinate conversions

@docs relativeTo, placeIn, projectInto


# Subdivision

@docs bisect, splitAt


# Arc length parameterization

@docs ArcLengthParameterized, arcLengthParameterized, arcLength, pointAlong, tangentAlong, arcLengthToParameterValue, parameterValueToArcLength, underlyingSpline


# Low level

Low level functionality that you are unlikely to need to use directly.

@docs secondDerivative, secondDerivatives, derivativeMagnitude, maxSecondDerivativeMagnitude

-}

import ArcLength
import Axis3d exposing (Axis3d)
import BoundingBox3d exposing (BoundingBox3d)
import CubicSpline2d exposing (CubicSpline2d)
import Direction3d exposing (Direction3d)
import Frame3d exposing (Frame3d)
import Geometry.Accuracy exposing (Accuracy)
import Geometry.Types as Types
import Plane3d exposing (Plane3d)
import Point3d exposing (Point3d)
import QuadraticSpline3d exposing (QuadraticSpline3d)
import SketchPlane3d exposing (SketchPlane3d)
import Vector3d exposing (Vector3d)


{-| -}
type alias CubicSpline3d =
    Types.CubicSpline3d


{-| Construct a spline from its four control points:

    exampleSpline =
        CubicSpline3d.fromControlPoints
            ( Point3d.fromCoordinates ( 1, 1, 1 )
            , Point3d.fromCoordinates ( 3, 1, 1 )
            , Point3d.fromCoordinates ( 3, 3, 1 )
            , Point3d.fromCoordinates ( 3, 3, 3 )
            )

-}
fromControlPoints : ( Point3d, Point3d, Point3d, Point3d ) -> CubicSpline3d
fromControlPoints =
    Types.CubicSpline3d


{-| Construct a spline from a given start point with a given start derivative,
to a given end point with a given end derivative, like so:

![Cubic spline from endpoints](https://ianmackenzie.github.io/elm-geometry/1.0.0/CubicSpline2d/from.svg)

The spline is based on a parameter that ranges from 0 to 1; as a result, in most
cases the length of each derivative vector should be roughly equal to the length
of the resulting spline.

-}
from : ( Point3d, Vector3d ) -> ( Point3d, Vector3d ) -> CubicSpline3d
from ( startPoint, startDerivative ) ( endPoint, endDerivative ) =
    let
        startControlPoint =
            startPoint
                |> Point3d.translateBy
                    (Vector3d.scaleBy (1 / 3) startDerivative)

        endControlPoint =
            endPoint
                |> Point3d.translateBy
                    (Vector3d.scaleBy (-1 / 3) endDerivative)
    in
    fromControlPoints
        ( startPoint
        , startControlPoint
        , endControlPoint
        , endPoint
        )


{-| Construct a 3D spline lying _on_ a sketch plane by providing a 2D spline
specified in XY coordinates _within_ the sketch plane.

    CubicSpline3d.on SketchPlane3d.xz <|
        CubicSpline2d.fromControlPoints
            ( Point2d.fromCoordinates ( 1, 1 )
            , Point2d.fromCoordinates ( 3, 4 )
            , Point2d.fromCoordinates ( 5, 1 )
            , Point2d.fromCoordinates ( 7, 4 )
            )
    --> CubicSpline3d.fromControlPoints
    -->     ( Point3d.fromCoordinates ( 1, 0, 1 )
    -->     , Point3d.fromCoordinates ( 3, 0, 4 )
    -->     , Point3d.fromCoordinates ( 5, 0, 1 )
    -->     , Point3d.fromCoordinates ( 7, 0, 4 )
    -->     )

-}
on : SketchPlane3d -> CubicSpline2d -> CubicSpline3d
on sketchPlane spline =
    let
        ( p1, p2, p3, p4 ) =
            CubicSpline2d.controlPoints spline

        place =
            Point3d.on sketchPlane
    in
    fromControlPoints ( place p1, place p2, place p3, place p4 )


{-| Convert a quadratic spline into the equivalent cubic spline (every quadratic
spline can be represented exactly as a cubic spline).

    quadraticSpline =
        QuadraticSpline3d.fromControlPoints
            ( Point3d.fromCoordinates ( 0, 0, 0  )
            , Point3d.fromCoordinates ( 3, 0, 0 )
            , Point3d.fromCoordinates ( 3, 3, 0 )
            )

    CubicSpline3d.fromQuadraticSpline quadraticSpline
    --> CubicSpline3d.fromControlPoints
    -->     ( Point3d.fromCoordinates ( 0, 0, 0 )
    -->     , Point3d.fromCoordinates ( 2, 0, 0 )
    -->     , Point3d.fromCoordinates ( 3, 1, 0 )
    -->     , Point3d.fromCoordinates ( 3, 3, 0 )
    -->     )

-}
fromQuadraticSpline : QuadraticSpline3d -> CubicSpline3d
fromQuadraticSpline quadraticSpline =
    let
        ( p1, p2, p3 ) =
            QuadraticSpline3d.controlPoints quadraticSpline
    in
    fromControlPoints
        ( p1
        , Point3d.interpolateFrom p1 p2 (2 / 3)
        , Point3d.interpolateFrom p3 p2 (2 / 3)
        , p3
        )


{-| Get the control points of a spline as a tuple.

    ( p1, p2, p3, p4 ) =
        CubicSpline3d.controlPoints exampleSpline


    --> p1 = Point3d.fromCoordinates ( 1, 1, 1 )
    --> p2 = Point3d.fromCoordinates ( 3, 1, 1 )
    --> p3 = Point3d.fromCoordinates ( 3, 3, 1 )
    --> p4 = Point3d.fromCoordinates ( 3, 3, 3 )

-}
controlPoints : CubicSpline3d -> ( Point3d, Point3d, Point3d, Point3d )
controlPoints (Types.CubicSpline3d controlPoints_) =
    controlPoints_


{-| Get the start point of a spline. This is equal to the spline's first control
point.

    CubicSpline3d.startPoint exampleSpline
    --> Point3d.fromCoordinates ( 1, 1, 1 )

-}
startPoint : CubicSpline3d -> Point3d
startPoint (Types.CubicSpline3d ( p1, _, _, _ )) =
    p1


{-| Get the end point of a spline. This is equal to the spline's last control
point.

    CubicSpline3d.endPoint exampleSpline
    --> Point3d.fromCoordinates ( 3, 3, 3 )

-}
endPoint : CubicSpline3d -> Point3d
endPoint (Types.CubicSpline3d ( _, _, _, p4 )) =
    p4


{-| Get the start derivative of a spline. This is equal to three times the
vector from the spline's first control point to its second.

    CubicSpline3d.startDerivative exampleSpline
    --> Vector3d.fromComponents ( 6, 0, 0 )

-}
startDerivative : CubicSpline3d -> Vector3d
startDerivative spline =
    let
        ( p1, p2, _, _ ) =
            controlPoints spline
    in
    Vector3d.from p1 p2 |> Vector3d.scaleBy 3


{-| Get the end derivative of a spline. This is equal to three times the vector
from the spline's third control point to its fourth.

    CubicSpline3d.endDerivative exampleSpline
    --> Vector3d.fromComponents ( 0, 0, 6 )

-}
endDerivative : CubicSpline3d -> Vector3d
endDerivative spline =
    let
        ( _, _, p3, p4 ) =
            controlPoints spline
    in
    Vector3d.from p3 p4 |> Vector3d.scaleBy 3


{-| Compute a bounding box for a given spline. It is not guaranteed that the
result will be the _smallest_ possible bounding box, since for efficiency the
bounding box is computed from the spline's control points (which cover a larger
volume than the spline itself).

    CubicSpline3d.boundingBox exampleSpline
    --> BoundingBox3d.fromExtrema
    -->     { minX = 1
    -->     , maxX = 3
    -->     , minY = 1
    -->     , maxY = 3
    -->     , minZ = 1
    -->     , maxZ = 3
    -->     }

-}
boundingBox : CubicSpline3d -> BoundingBox3d
boundingBox spline =
    let
        ( p1, p2, p3, p4 ) =
            controlPoints spline

        ( x1, y1, z1 ) =
            Point3d.coordinates p1

        ( x2, y2, z2 ) =
            Point3d.coordinates p2

        ( x3, y3, z3 ) =
            Point3d.coordinates p3

        ( x4, y4, z4 ) =
            Point3d.coordinates p4
    in
    BoundingBox3d.fromExtrema
        { minX = min (min x1 x2) (min x3 x4)
        , maxX = max (max x1 x2) (max x3 x4)
        , minY = min (min y1 y2) (min y3 y4)
        , maxY = max (max y1 y2) (max y3 y4)
        , minZ = min (min z1 z2) (min z3 z4)
        , maxZ = max (max z1 z2) (max z3 z4)
        }


{-| Get a point along a spline, based on a parameter that ranges from 0 to 1. A
parameter value of 0 corresponds to the start point of the spline and a value of
1 corresponds to the end point.

    CubicSpline3d.pointOn exampleSpline 0
    --> Point3d.fromCoordinates ( 1, 1, 1 )

    CubicSpline3d.pointOn exampleSpline 0.5
    --> Point3d.fromCoordinates ( 2.75, 2, 1.25 )

    CubicSpline3d.pointOn exampleSpline 1
    --> Point3d.fromCoordinates ( 3, 3, 3 )

-}
pointOn : CubicSpline3d -> Float -> Point3d
pointOn spline t =
    let
        ( p1, p2, p3, p4 ) =
            controlPoints spline

        q1 =
            Point3d.interpolateFrom p1 p2 t

        q2 =
            Point3d.interpolateFrom p2 p3 t

        q3 =
            Point3d.interpolateFrom p3 p4 t

        r1 =
            Point3d.interpolateFrom q1 q2 t

        r2 =
            Point3d.interpolateFrom q2 q3 t
    in
    Point3d.interpolateFrom r1 r2 t


{-| Convenient shorthand for evaluating multiple points;

    CubicSpline3d.pointsOn spline parameterValues

is equivalent to

    List.map (CubicSpline3d.pointOn spline) parameterValues

To generate evenly-spaced parameter values, check out the [`Parameter`](Geometry-Parameter)
module.

-}
pointsOn : CubicSpline3d -> List Float -> List Point3d
pointsOn spline parameterValues =
    List.map (pointOn spline) parameterValues


{-| Get the derivative vector at a point along a spline, based on a parameter
that ranges from 0 to 1. A parameter value of 0 corresponds to the start
derivative of the spline and a value of 1 corresponds to the end derivative.

    CubicSpline3d.derivative exampleSpline 0
    --> Vector3d.fromComponents ( 6, 0, 0 )

    CubicSpline3d.derivative exampleSpline 0.5
    --> Vector3d.fromComponents ( 1.5, 3, 1.5 )

    CubicSpline3d.derivative exampleSpline 1
    --> Vector3d.fromComponents ( 0, 0, 6 )

Note that the derivative interpolates linearly from end to end.

-}
derivative : CubicSpline3d -> Float -> Vector3d
derivative spline t =
    let
        ( p1, p2, p3, p4 ) =
            controlPoints spline

        ( x1, y1, z1 ) =
            Point3d.coordinates p1

        ( x2, y2, z2 ) =
            Point3d.coordinates p2

        ( x3, y3, z3 ) =
            Point3d.coordinates p3

        ( x4, y4, z4 ) =
            Point3d.coordinates p4

        vx1 =
            x2 - x1

        vy1 =
            y2 - y1

        vz1 =
            z2 - z1

        vx2 =
            x3 - x2

        vy2 =
            y3 - y2

        vz2 =
            z3 - z2

        vx3 =
            x4 - x3

        vy3 =
            y4 - y3

        vz3 =
            z4 - z3
    in
    if t <= 0.5 then
        let
            wx1 =
                vx1 + t * (vx2 - vx1)

            wy1 =
                vy1 + t * (vy2 - vy1)

            wz1 =
                vz1 + t * (vz2 - vz1)

            wx2 =
                vx2 + t * (vx3 - vx2)

            wy2 =
                vy2 + t * (vy3 - vy2)

            wz2 =
                vz2 + t * (vz3 - vz2)
        in
        Vector3d.fromComponents
            ( 3 * (wx1 + t * (wx2 - wx1))
            , 3 * (wy1 + t * (wy2 - wy1))
            , 3 * (wz1 + t * (wz2 - wz1))
            )
    else
        let
            u =
                1 - t

            wx1 =
                vx2 + u * (vx1 - vx2)

            wy1 =
                vy2 + u * (vy1 - vy2)

            wz1 =
                vz2 + u * (vz1 - vz2)

            wx2 =
                vx3 + u * (vx2 - vx3)

            wy2 =
                vy3 + u * (vy2 - vy3)

            wz2 =
                vz3 + u * (vz2 - vz3)
        in
        Vector3d.fromComponents
            ( 3 * (wx2 + u * (wx1 - wx2))
            , 3 * (wy2 + u * (wy1 - wy2))
            , 3 * (wz2 + u * (wz1 - wz2))
            )


{-| Convenient shorthand for evaluating multiple derivatives;

    CubicSpline3d.derivatives spline parameterValues

is equivalent to

    List.map (CubicSpline3d.derivative spline) parameterValues

To generate evenly-spaced parameter values, check out the [`Parameter`](Geometry-Parameter)
module.

-}
derivatives : CubicSpline3d -> List Float -> List Vector3d
derivatives spline parameterValues =
    List.map (derivative spline) parameterValues


{-| Find the magnitude of the derivative to a spline at a particular parameter
value;

    CubicSpline3d.derivativeMagnitude spline t

is equivalent to

    Vector3d.length (CubicSpline3d.derivative spline t)

but more efficient since it avoids any intermediate `Vector3d` allocation.

-}
derivativeMagnitude : CubicSpline3d -> Float -> Float
derivativeMagnitude spline =
    let
        ( p1, p2, p3, p4 ) =
            controlPoints spline

        ( x1, y1, z1 ) =
            Point3d.coordinates p1

        ( x2, y2, z2 ) =
            Point3d.coordinates p2

        ( x3, y3, z3 ) =
            Point3d.coordinates p3

        ( x4, y4, z4 ) =
            Point3d.coordinates p4

        x12 =
            x2 - x1

        y12 =
            y2 - y1

        z12 =
            z2 - z1

        x23 =
            x3 - x2

        y23 =
            y3 - y2

        z23 =
            z3 - z2

        x34 =
            x4 - x3

        y34 =
            y4 - y3

        z34 =
            z4 - z3

        x123 =
            x23 - x12

        y123 =
            y23 - y12

        z123 =
            z23 - z12

        x234 =
            x34 - x23

        y234 =
            y34 - y23

        z234 =
            z34 - z23
    in
    \t ->
        let
            x13 =
                x12 + t * x123

            y13 =
                y12 + t * y123

            z13 =
                z12 + t * z123

            x24 =
                x23 + t * x234

            y24 =
                y23 + t * y234

            z24 =
                z23 + t * z234

            x14 =
                x13 + t * (x24 - x13)

            y14 =
                y13 + t * (y24 - y13)

            z14 =
                z13 + t * (z24 - z13)
        in
        3 * sqrt (x14 * x14 + y14 * y14 + z14 * z14)


{-| Sample a spline at a given parameter value to get both the position and
derivative vector at that parameter value;

    CubicSpline3d.sample spline t

is equivalent to

    ( CubicSpline3d.pointOn spline t
    , CubicSpline3d.derivative spline t
    )

but is more efficient.

-}
sample : CubicSpline3d -> Float -> ( Point3d, Vector3d )
sample spline t =
    let
        ( p1, p2, p3, p4 ) =
            controlPoints spline

        q1 =
            Point3d.interpolateFrom p1 p2 t

        q2 =
            Point3d.interpolateFrom p2 p3 t

        q3 =
            Point3d.interpolateFrom p3 p4 t

        r1 =
            Point3d.interpolateFrom q1 q2 t

        r2 =
            Point3d.interpolateFrom q2 q3 t
    in
    ( Point3d.interpolateFrom r1 r2 t
    , Vector3d.from r1 r2 |> Vector3d.scaleBy 3
    )


{-| Convenient shorthand for evaluating multiple samples;

    CubicSpline3d.samples spline parameterValues

is equivalent to

    List.map (CubicSpline3d.sample spline) parameterValues

To generate evenly-spaced parameter values, check out the [`Parameter`](Geometry-Parameter)
module.

-}
samples : CubicSpline3d -> List Float -> List ( Point3d, Vector3d )
samples spline parameterValues =
    List.map (sample spline) parameterValues


mapControlPoints : (Point3d -> Point3d) -> CubicSpline3d -> CubicSpline3d
mapControlPoints function spline =
    let
        ( p1, p2, p3, p4 ) =
            controlPoints spline
    in
    fromControlPoints ( function p1, function p2, function p3, function p4 )


{-| Reverse a spline so that the start point becomes the end point, and vice
versa.

    CubicSpline3d.reverse exampleSpline
    --> CubicSpline3d.fromControlPoints
    -->     ( Point3d.fromCoordinates ( 3, 3, 3 )
    -->     , Point3d.fromCoordinates ( 3, 3, 1 )
    -->     , Point3d.fromCoordinates ( 3, 1, 1 )
    -->     , Point3d.fromCoordinates ( 1, 1, 1 )
    -->     )

-}
reverse : CubicSpline3d -> CubicSpline3d
reverse spline =
    let
        ( p1, p2, p3, p4 ) =
            controlPoints spline
    in
    fromControlPoints ( p4, p3, p2, p1 )


{-| Scale a spline about the given center point by the given scale.

    CubicSpline3d.scaleAbout Point3d.origin 2 exampleSpline
    --> CubicSpline3d.fromControlPoints
    -->     ( Point3d.fromCoordinates ( 2, 2, 2 )
    -->     , Point3d.fromCoordinates ( 6, 2, 2 )
    -->     , Point3d.fromCoordinates ( 6, 6, 2 )
    -->     , Point3d.fromCoordinates ( 6, 6, 6 )
    -->     )

-}
scaleAbout : Point3d -> Float -> CubicSpline3d -> CubicSpline3d
scaleAbout point scale =
    mapControlPoints (Point3d.scaleAbout point scale)


{-| Rotate a spline counterclockwise around a given axis by a given angle (in
radians).

    exampleSpline
        |> CubicSpline3d.rotateAround Axis3d.z (degrees 90)
    --> CubicSpline3d.fromControlPoints
    -->     ( Point3d.fromCoordinates ( -1, 1, 1 )
    -->     , Point3d.fromCoordinates ( -1, 3, 1 )
    -->     , Point3d.fromCoordinates ( -3, 3, 1 )
    -->     , Point3d.fromCoordinates ( -3, 3, 3 )
    -->     )

-}
rotateAround : Axis3d -> Float -> CubicSpline3d -> CubicSpline3d
rotateAround axis angle =
    mapControlPoints (Point3d.rotateAround axis angle)


{-| Translate a spline by a given displacement.

    displacement =
        Vector3d.fromComponents ( 2, 3, 1 )

    CubicSpline3d.translateBy displacement exampleSpline
    --> CubicSpline3d.fromControlPoints
    -->     ( Point3d.fromCoordinates ( 3, 4, 2 )
    -->     , Point3d.fromCoordinates ( 5, 4, 2 )
    -->     , Point3d.fromCoordinates ( 5, 6, 2 )
    -->     , Point3d.fromCoordinates ( 5, 6, 4 )
    -->     )

-}
translateBy : Vector3d -> CubicSpline3d -> CubicSpline3d
translateBy displacement =
    mapControlPoints (Point3d.translateBy displacement)


{-| Translate a spline in a given direction by a given distance;

    CubicSpline3d.translateIn direction distance

is equivalent to

    CubicSpline3d.translateBy
        (Vector3d.withLength distance direction)

-}
translateIn : Direction3d -> Float -> CubicSpline3d -> CubicSpline3d
translateIn direction distance spline =
    translateBy (Vector3d.withLength distance direction) spline


{-| Mirror a spline across a plane.

    CubicSpline3d.mirrorAcross Plane3d.xy exampleSpline
    --> CubicSpline3d.fromControlPoints
    -->     ( Point3d.fromCoordinates ( 1, 1, -1 )
    -->     , Point3d.fromCoordinates ( 3, 1, -1 )
    -->     , Point3d.fromCoordinates ( 3, 3, -1 )
    -->     , Point3d.fromCoordinates ( 3, 3, -3 )
    -->     )

-}
mirrorAcross : Plane3d -> CubicSpline3d -> CubicSpline3d
mirrorAcross plane =
    mapControlPoints (Point3d.mirrorAcross plane)


{-| Find the [orthographic projection](https://en.wikipedia.org/wiki/Orthographic_projection)
of a spline onto a plane.

    CubicSpline3d.projectOnto Plane3d.xy exampleSpline
    --> CubicSpline3d.fromControlPoints
    -->     ( Point3d.fromCoordinates ( 1, 1, 0 )
    -->     , Point3d.fromCoordinates ( 3, 1, 0 )
    -->     , Point3d.fromCoordinates ( 3, 3, 0 )
    -->     , Point3d.fromCoordinates ( 3, 3, 0 )
    -->     )

-}
projectOnto : Plane3d -> CubicSpline3d -> CubicSpline3d
projectOnto plane =
    mapControlPoints (Point3d.projectOnto plane)


{-| Take a spline defined in global coordinates, and return it expressed in
local coordinates relative to a given reference frame.

    localFrame =
        Frame3d.atPoint
            (Point3d.fromCoordinates ( 1, 2, 3 ))

    CubicSpline3d.relativeTo localFrame exampleSpline
    --> CubicSpline3d.fromControlPoints
    -->     ( Point3d.fromCoordinates ( 0, -1, -2 )
    -->     , Point3d.fromCoordinates ( 2, -1, -2 )
    -->     , Point3d.fromCoordinates ( 2, 1, -2 )
    -->     , Point3d.fromCoordinates ( 2, 1, 0 )
    -->     )

-}
relativeTo : Frame3d -> CubicSpline3d -> CubicSpline3d
relativeTo frame =
    mapControlPoints (Point3d.relativeTo frame)


{-| Take a spline considered to be defined in local coordinates relative to a
given reference frame, and return that spline expressed in global coordinates.

    localFrame =
        Frame3d.atPoint
            (Point3d.fromCoordinates ( 1, 2, 3 ))

    CubicSpline3d.placeIn localFrame exampleSpline
    --> CubicSpline3d.fromControlPoints
    -->     ( Point3d.fromCoordinates ( 2, 3, 4 )
    -->     , Point3d.fromCoordinates ( 4, 3, 4 )
    -->     , Point3d.fromCoordinates ( 4, 5, 4 )
    -->     , Point3d.fromCoordinates ( 4, 5, 6 )
    -->     )

-}
placeIn : Frame3d -> CubicSpline3d -> CubicSpline3d
placeIn frame =
    mapControlPoints (Point3d.placeIn frame)


{-| Project a spline into a given sketch plane. Conceptually, this finds the
[orthographic projection](https://en.wikipedia.org/wiki/Orthographic_projection)
of the spline onto the plane and then expresses the projected spline in 2D
sketch coordinates.

    exampleSpline
        |> CubicSpline3d.projectInto SketchPlane3d.yz
    --> CubicSpline2d.fromControlPoints
    -->     ( Point2d.fromCoordinates ( 1, 1 )
    -->     , Point2d.fromCoordinates ( 1, 1 )
    -->     , Point2d.fromCoordinates ( 3, 1 )
    -->     , Point2d.fromCoordinates ( 3, 3 )
    -->     )

-}
projectInto : SketchPlane3d -> CubicSpline3d -> CubicSpline2d
projectInto sketchPlane spline =
    let
        ( p1, p2, p3, p4 ) =
            controlPoints spline

        project =
            Point3d.projectInto sketchPlane
    in
    CubicSpline2d.fromControlPoints
        ( project p1
        , project p2
        , project p3
        , project p4
        )


{-| Split a spline into two roughly equal halves. Equivalent to `splitAt 0.5`.

    CubicSpline3d.bisect exampleSpline
    --> ( CubicSpline3d.fromControlPoints
    -->     ( Point3d.fromCoordinates ( 1, 1, 1 )
    -->     , Point3d.fromCoordinates ( 2, 1, 1 )
    -->     , Point3d.fromCoordinates ( 2.5, 1.5, 1 )
    -->     , Point3d.fromCoordinates ( 2.75, 2, 1.25 )
    -->     )
    --> , CubicSpline3d.fromControlPoints
    -->     ( Point3d.fromCoordinates ( 2.75, 2, 1.25 )
    -->     , Point3d.fromCoordinates ( 3, 2.5, 1.5 )
    -->     , Point3d.fromCoordinates ( 3, 3, 2 )
    -->     , Point3d.fromCoordinates ( 3, 3, 3 )
    -->     )
    --> )

-}
bisect : CubicSpline3d -> ( CubicSpline3d, CubicSpline3d )
bisect =
    splitAt 0.5


{-| Split a spline at a particular parameter value (in the range 0 to 1),
resulting in two smaller splines.

    CubicSpline3d.splitAt 0.75 exampleSpline
    --> ( CubicSpline3d.fromControlPoints
    -->     ( Point3d.fromCoordinates ( 1, 1, 1 )
    -->     , Point3d.fromCoordinates ( 2.5, 1, 1 )
    -->     , Point3d.fromCoordinates ( 2.88, 2.13, 1 )
    -->     , Point3d.fromCoordinates ( 2.97, 2.69, 1.84 )
    -->     )
    --> , CubicSpline3d.fromControlPoints
    -->     ( Point3d.fromCoordinates ( 2.97, 2.69, 1.84 )
    -->     , Point3d.fromCoordinates ( 3, 2.88, 2.13 )
    -->     , Point3d.fromCoordinates ( 3, 3, 2.5 )
    -->     , Point3d.fromCoordinates ( 3, 3, 3 )
    -->     )
    --> )

-}
splitAt : Float -> CubicSpline3d -> ( CubicSpline3d, CubicSpline3d )
splitAt t spline =
    let
        ( p1, p2, p3, p4 ) =
            controlPoints spline

        q1 =
            Point3d.interpolateFrom p1 p2 t

        q2 =
            Point3d.interpolateFrom p2 p3 t

        q3 =
            Point3d.interpolateFrom p3 p4 t

        r1 =
            Point3d.interpolateFrom q1 q2 t

        r2 =
            Point3d.interpolateFrom q2 q3 t

        s =
            Point3d.interpolateFrom r1 r2 t
    in
    ( fromControlPoints ( p1, q1, r1, s )
    , fromControlPoints ( s, r2, q3, p4 )
    )


{-| A spline that has been parameterized by arc length.
-}
type ArcLengthParameterized
    = ArcLengthParameterized CubicSpline3d ArcLength.Parameterization


{-| Build an arc length parameterization of the given spline:

    parameterizedSpline =
        CubicSpline3d.arcLengthParameterized
            (Accuracy.maxError 1.0e-4)
            exampleSpline

The accuracy of the parameterization is controlled by the first argument; this
affects the accuracy of results returned from functions such as `arcLength` and
`pointAlong`.

-}
arcLengthParameterized : Accuracy -> CubicSpline3d -> ArcLengthParameterized
arcLengthParameterized (Types.MaxError tolerance) spline =
    let
        parameterization =
            ArcLength.parameterization
                { tolerance = tolerance
                , derivativeMagnitude = derivativeMagnitude spline
                , maxSecondDerivativeMagnitude =
                    maxSecondDerivativeMagnitude spline
                }
    in
    ArcLengthParameterized spline parameterization


{-| Find the total arc length of a spline:

    CubicSpline3d.arcLength parameterizedSpline
    --> 4.3303

In this example, the result will be accurate to within `1.0e-4` since that was
the tolerance used when constructing `parameterizedSpline`.

-}
arcLength : ArcLengthParameterized -> Float
arcLength (ArcLengthParameterized _ parameterization) =
    ArcLength.fromParameterization parameterization


{-| Try to get the point along a spline at a given arc length. For example, to
get the point a quarter of the way along `exampleSpline`:

    CubicSpline3d.pointAlong parameterizedSpline
        (arcLength / 4)
    --> Just <|
    -->     Point3d.fromCoordinates
    -->         ( 2.0425, 1.2431, 1.0206 )

Note that this is not the same as evaulating at a parameter value of 1/4:

    CubicSpline3d.pointOn exampleSpline 0.25
    --> Point3d.fromCoordinates ( 2.1563, 1.3125, 1.0313 )

If the given arc length is less than zero or greater than the arc length of the
spline, `Nothing` is returned.

-}
pointAlong : ArcLengthParameterized -> Float -> Maybe Point3d
pointAlong (ArcLengthParameterized spline parameterization) s =
    ArcLength.toParameterValue parameterization s |> Maybe.map (pointOn spline)


{-| Try to get the tangent direction along a spline at a given arc length. To
get the tangent direction a quarter of the way along `exampleSpline`:

    CubicSpline3d.tangentAlong parameterizedSpline
        (arcLength / 4)
    --> Just <|
    -->     Direction3d.fromAzimuthAndElevation
    -->         ( degrees 29.0995, degrees 3.8713 )

If the given arc length is less than zero or greater than the arc length of the
spline (or if the derivative of the spline happens to be exactly zero at the
given arc length), `Nothing` is returned.

-}
tangentAlong : ArcLengthParameterized -> Float -> Maybe Direction3d
tangentAlong (ArcLengthParameterized spline parameterization) s =
    ArcLength.toParameterValue parameterization s
        |> Maybe.map (derivative spline)
        |> Maybe.andThen Vector3d.direction


{-| Try to get the parameter value along a spline at a given arc length. If the
given arc length is less than zero or greater than the arc length of the spline,
returns `Nothing`.

    CubicSpline3d.arcLengthToParameterValue
        parameterizedSpline
        (arcLength / 4)
    --> Just 0.2177

-}
arcLengthToParameterValue : ArcLengthParameterized -> Float -> Maybe Float
arcLengthToParameterValue (ArcLengthParameterized _ parameterization) s =
    ArcLength.toParameterValue parameterization s


{-| Try to get the arc length along a spline at a given parameter value. If the
given parameter value is less than zero or greater than one, returns `Nothing`.

    CubicSpline3d.parameterValueToArcLength
        parameterizedSpline
        0.25
    --> Just 1.2163

-}
parameterValueToArcLength : ArcLengthParameterized -> Float -> Maybe Float
parameterValueToArcLength (ArcLengthParameterized _ parameterization) t =
    ArcLength.fromParameterValue parameterization t


{-| Get the original `CubicSpline3d` from which an `ArcLengthParameterized`
value was constructed.
-}
underlyingSpline : ArcLengthParameterized -> CubicSpline3d
underlyingSpline (ArcLengthParameterized spline _) =
    spline


{-| Find an upper bound on the magnitude of the second derivative of a spline.
-}
maxSecondDerivativeMagnitude : CubicSpline3d -> Float
maxSecondDerivativeMagnitude spline =
    let
        ( p1, p2, p3, p4 ) =
            controlPoints spline

        u1 =
            Vector3d.from p1 p2

        u2 =
            Vector3d.from p2 p3

        u3 =
            Vector3d.from p3 p4

        v1 =
            Vector3d.difference u2 u1

        v2 =
            Vector3d.difference u3 u2
    in
    6 * max (Vector3d.length v1) (Vector3d.length v2)


{-| Get the second derivative value at a point along a spline, based on a
parameter that ranges from 0 to 1. A parameter value of 0 corresponds to the
start of the spline and a value of 1 corresponds to the end.

    CubicSpline3d.secondDerivative exampleSpline 0
    --> Vector3d.fromComponents ( -12, 12, 0 )

    CubicSpline3d.secondDerivative exampleSpline 0.5
    --> Vector3d.fromComponents ( -6, 0, 6 )

    CubicSpline3d.secondDerivative exampleSpline 1
    --> Vector3d.fromComponents ( 0, -12, 12 )

-}
secondDerivative : CubicSpline3d -> Float -> Vector3d
secondDerivative spline t =
    let
        ( p1, p2, p3, p4 ) =
            controlPoints spline

        u1 =
            Vector3d.from p1 p2

        u2 =
            Vector3d.from p2 p3

        u3 =
            Vector3d.from p3 p4

        v1 =
            Vector3d.difference u2 u1

        v2 =
            Vector3d.difference u3 u2
    in
    Vector3d.scaleBy 6 (Vector3d.interpolateFrom v1 v2 t)


{-| Convenient shorthand for evaluating multiple second derivatives;

    CubicSpline3d.secondDerivatives spline parameterValues

is equivalent to

    List.map (CubicSpline3d.secondDerivative spline)
        parameterValues

To generate evenly-spaced parameter values, check out the [`Parameter`](Geometry-Parameter)
module.

-}
secondDerivatives : CubicSpline3d -> List Float -> List Vector3d
secondDerivatives spline parameterValues =
    List.map (secondDerivative spline) parameterValues
