"""Render Brandt's service-window fixture, glass drip pot and pouring cup."""
import math
from bisect import bisect_right
from generate_recovery_sounds import bake, sine, strike


def tubes(t, low, band, bright):
    # A pair of 60 Hz magnetic ballasts behind the service-window diffuser.
    mains = sine(120, t) + .52*sine(240, t) + .18*sine(360, t)
    cover = sine(480, t) + .24*sine(960, t)
    return .23*mains + .062*(.89+.11*sine(.5,t))*cover + .09*band + .015*bright


def drips(t, times, pitch):
    index = bisect_right(times, t) - 1
    if index < 0:
        return 0.
    dt = t-times[index]
    # A drop strikes the pool and the entrained air bubble rings upward.
    return math.exp(-dt*73) * sine(pitch*(.79+.31*(1-math.exp(-dt*115))),dt)


DRIPS = [.94, 1.39, 1.75, 2.01, 2.23, 2.41, 2.60, 2.74, 2.92, 3.08, 3.22,
         3.4, 3.55, 3.73, 3.89, 4.01, 4.17, 4.33, 4.47, 4.63, 4.84,
         5.02, 5.22, 5.41, 5.68, 6.00, 6.35, 6.78, 7.37, 8.13, 9.04]
BURSTS = [.38, .86, 1.42, 2.18, 2.97, 3.65, 4.31, 5.16, 5.89]


def brew(t, low, band, bright):
    heater = (1-math.exp(-t*3)) * min(1.,max(0.,(6.9-t)/2.5))
    gurgle = sum(strike(t, onset, .17) for onset in BURSTS)
    rumble = (.65+.35*sine(12,t))*(.13*sine(112,t)+.18*sine(176,t)+.61*low)
    basket = max(0., 1-abs(t-3.8)/2.5) * (.25*band+.105*bright)
    cutout = strike(t, 6.47, .018) * (.60*bright+.40*sine(1630,t))
    return heater*(.026*sine(120,t)+.09*low) + gurgle*rumble + basket + .26*drips(t,DRIPS,834) + cutout


def pour(t, low, band, bright):
    stream = min(1.,max(0.,(t-.27)*4.1)) * min(1.,max(0.,(1.68-t)*4.8))
    splash = .40*band + .28*bright + .19*low + .062*sine(440+160*t,t)
    glass = strike(t,.097,.048)*(.36*sine(1402,t)+.17*sine(2123,t))
    set_down = strike(t,1.96,.061)*(.35*low+.27*sine(339,t)+.16*sine(1780,t))
    return glass + stream*splash*(.91+.09*sine(19.7,t)) + .22*drips(t,[1.63,1.77,1.86],1120) + set_down


if __name__ == "__main__":
    bake("office_tubes", tubes, 8., True, 241)
    bake("coffee_brew", brew, 9.55, False, 249)
    bake("coffee_pour", pour, 2.25, False, 267)
