-- Metric Temporal Logic (MTL) operators over a discrete time
-- domain consisting of sampled time values

module Copilot.Library.MTL
  ( eventually, eventuallyPrev, always, alwaysBeen,
    until, release, since, Copilot.Library.MTL.trigger, matchingUntil,
    matchingRelease, matchingSince, matchingTrigger ) where

import Copilot.Language
import qualified Prelude as P
import Copilot.Library.Utils

-- It is necessary to provide a positive number of time units
-- dist to each function, where the distance between the times
-- of any two adjacent clock samples is no less than dist

-- Eventually: True at time t iff s is true at some time t',
-- where (t + l) <= t' <= (t + u)
eventually :: ( Typed a, Integral a ) =>
  a -> a -> Stream a -> a -> Stream Bool -> Stream Bool
eventually l u clk dist s = res clk s $ (u `P.div` dist) + 1
  where
  mins = clk + (constant l)
  maxes = clk + (constant u)
  res _ _ 0 = false
  res c s k =
    c <= maxes && ((mins <= c && s) || nextRes c s k)
  nextRes c s k = res (drop 1 c) (drop 1 s) (k - 1)

-- EventuallyPrev: True at time t iff s is true at some time t',
-- where (t - u) <= t' <= (t - l)
eventuallyPrev :: ( Typed a, Integral a ) =>
  a -> a -> Stream a -> a -> Stream Bool -> Stream Bool
eventuallyPrev l u clk dist s = res clk s $ (u `P.div` dist) + 1
  where
  mins = clk - (constant u)
  maxes = clk - (constant l)
  res _ _ 0 = false
  res c s k =
    mins <= c && ((c <= maxes && s) || nextRes c s k)
  nextRes c s k = res ([0] ++ c) ([False] ++ s) (k - 1)

-- Always: True at time t iff s is true at all times t'
-- where (t + l) <= t' <= (t + u)
always :: ( Typed a, Integral a ) =>
  a -> a -> Stream a -> a -> Stream Bool -> Stream Bool
always l u clk dist s = res clk s $ (u `P.div` dist) + 1
  where 
  mins = clk + (constant l)
  maxes = clk + (constant u)
  res _ _ 0 = true 
  res c s k = 
    c > maxes || ((mins <= c ==> s) && nextRes c s k)
  nextRes c s k = res (drop 1 c) (drop 1 s) (k - 1)

-- AlwaysBeen: True at time t iff s is true at all times t'
-- where (t - u) <= t' <= (t - l)
alwaysBeen :: ( Typed a, Integral a ) =>
  a -> a -> Stream a -> a -> Stream Bool -> Stream Bool
alwaysBeen l u clk dist s = res clk s $ (u `P.div` dist) + 1
  where
  mins = clk - (constant u)
  maxes = clk - (constant l)
  res _ _ 0 = true
  res c s k =
    c < mins || ((c <= maxes ==> s) && nextRes c s k)
  nextRes c s k = res ([0] ++ c) ([True] ++ s) (k - 1)

-- Until: True at time t iff there exists a d with l <= d <= u
-- such that s1 is true at time (t + d),
-- and for all times t' with t <= t' < t + d, s0 is true
until :: ( Typed a, Integral a ) =>
  a -> a -> Stream a -> a -> Stream Bool -> Stream Bool -> Stream Bool
until l u clk dist s0 s1 = res clk s0 s1 $ (u `P.div` dist) + 1
  where
  mins = clk + (constant l)
  maxes = clk + (constant u)
  res _ _ _ 0 = false
  res c s s' k =
    c <= maxes && ((mins <= c && s') || (s && nextRes c s s' k))
  nextRes c s s' k = res (drop 1 c) (drop 1 s) (drop 1 s') (k - 1)

-- Since: True at time t iff there exists a d with l <= d <= u
-- such that s1 is true at time (t - d),
-- and for all times t' with t - d < t' <= t, s0 is true
since :: ( Typed a, Integral a ) =>
  a -> a -> Stream a -> a -> Stream Bool -> Stream Bool -> Stream Bool
since l u clk dist s0 s1 = res clk s0 s1 $ (u `P.div` dist) + 1
  where
  mins = clk - (constant u)
  maxes = clk - (constant l)
  res _ _ _ 0 = false 
  res c s s' k =
    mins <= c && ((c <= maxes && s') || (s && nextRes c s s' k))
  nextRes c s s' k = res ([0] ++ c) ([True] ++ s) ([False] ++ s') (k - 1)

-- Release: true at time t iff for all d with l <= d <= u where there
-- is a sample at time (t + d), s1 is true at time (t + d),
-- or s0 has a true sample at some time t' with t <= t' < t + d
release :: ( Typed a, Integral a ) =>
  a -> a -> Stream a -> a -> Stream Bool -> Stream Bool -> Stream Bool
release l u clk dist s0 s1 =
  (mins > clk || clk > maxes || s1) &&
  (res (drop 1 clk) s0 (drop 1 s1) $ u `P.div` dist)
  where
  mins = clk + (constant l)
  maxes = clk + (constant u)
  res _ _ _ 0 = true
  res c s s' k =
    s || ((mins > c || c > maxes || s') && nextRes c s s' k)
  nextRes c s s' k = res (drop 1 c) (drop 1 s) (drop 1 s') (k - 1)

-- Trigger: True at time t iff for all d with l <= d <= u where there
-- is a sample at time (t - d), s1 is true at time (t - d),
-- or s0 has a true sample at some time t' with t - d < t' <= t 
trigger :: ( Typed a, Integral a ) =>
  a -> a -> Stream a -> a -> Stream Bool -> Stream Bool -> Stream Bool
trigger l u clk dist s0 s1 =
  (mins > clk || clk > maxes || s1) &&
  (res ([0] ++ clk) s0 ([True] ++ s1) $ u `P.div` dist)
  where
  mins = clk - (constant u)
  maxes = clk - (constant l)
  res _ _ _ 0 = true
  res c s s' k =
    s || ((mins > c || c > maxes || s') && nextRes c s s' k)
  nextRes c s s' k = res ([0] ++ c) ([False] ++ s) ([True] ++ s') (k - 1)

-- Matching Variants

-- Matching Until: Same semantics as Until, except with both s1 and s0
-- needing to hold at time (t + d) instead of just s1
matchingUntil :: ( Typed a, Integral a ) =>
  a -> a -> Stream a -> a -> Stream Bool -> Stream Bool -> Stream Bool
matchingUntil l u clk dist s0 s1 = res clk s0 s1 $ (u `P.div` dist) + 1
  where
  mins = clk + (constant l)
  maxes = clk + (constant u)
  res _ _ _ 0 = false
  res c s s' k =
    c <= maxes && s && ((mins <= c && s') || nextRes c s s' k)
  nextRes c s s' k = res (drop 1 c) (drop 1 s) (drop 1 s') (k - 1)

-- Matching Since: Same semantics as Since, except with both s1 and s0
-- needing to hold at time (t - d) instead of just s1
matchingSince :: ( Typed a, Integral a ) =>
  a -> a -> Stream a -> a -> Stream Bool -> Stream Bool -> Stream Bool
matchingSince l u clk dist s0 s1 = since l u clk dist s0 (s0 && s1)

-- Matching Release: Same semantics as Release, except with
-- s1 or s0 needing to hold at time (t + d) instead of just s1
matchingRelease :: ( Typed a, Integral a ) =>
  a -> a -> Stream a -> a -> Stream Bool -> Stream Bool -> Stream Bool
matchingRelease l u clk dist s0 s1 = res clk s0 s1 $ (u `P.div` dist) + 1
  where
  mins = clk + (constant l)
  maxes = clk + (constant u)
  res _ _ _ 0 = true
  res c s s' k =
    s || ((mins > c || c > maxes || s') && nextRes c s s' k)
  nextRes c s s' k = res (drop 1 c) (drop 1 s) (drop 1 s') (k - 1)

-- Matching Trigger: Same semantics as Trigger, except with
-- s1 or s0 needing to hold at time (t - d) instead of just s1
matchingTrigger :: ( Typed a, Integral a ) =>
  a -> a -> Stream a -> a -> Stream Bool -> Stream Bool -> Stream Bool
matchingTrigger l u clk dist s0 s1 =
  Copilot.Library.MTL.trigger l u clk dist s0 (s0 || s1)
