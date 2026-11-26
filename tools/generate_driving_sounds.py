"""Bake the chain crosslinks, wiper rubber and diesel exhaust brake."""
import math

from generate_recovery_sounds import bake, sine, strike


def link(t, low, band, bright):
    impact = strike(t, .004, .018)
    bounce = strike(t, .023, .023)
    ring = .34*sine(1240, t)+.14*sine(2181, t)+.12*sine(681, t)
    return impact*(ring+.48*band+.64*bright)+bounce*(.46*band+.23*bright)


def chain_run(t, low, band, bright):
    # Two tandem drive axles press staggered crosslinks onto the pavement.
    period = 1/18
    left = link(t % period, low, band, bright)
    right = link((t + .031) % period, low, band, bright)
    return .70*left+.41*right+(.16+.08*sine(3, t))*low


def wipers(t, low, band, bright):
    # The linkage rocks twice on one revolution of its motor. The glass
    # squeaks briefly near each end. The blade parks after the return.
    arc = abs(math.sin(math.pi*t/.48))
    blade = arc**.55
    friction = .08*sine(618 if t<.48 else 492, t+.00025*sine(9.375, t))
    reversal = strike(t, .469, .021) + .78*strike(t, .928, .024)
    rubber = (.69*band+.22*bright+friction)*blade
    linkage = (.065*sine(98, t)+.066*sine(196, t))*(.48+.52*blade)
    return rubber+linkage+reversal*(.60*low+.34*sine(223, t))


def exhaust_brake(t, low, band, bright):
    # An inline six on overrun sends three exhaust pulses per revolution.
    # At the reference 1320 RPM the note repeats at 66 Hz.
    train = (max(0, sine(66, t + .00016*sine(3, t))))**5
    resonance = .16*sine(132, t)+.094*sine(198, t)+.073*sine(330, t)
    return (train-.178)*.66 + resonance + (.40+1.1*train)*low + (.24+.68*train)*band + .047*bright


if __name__ == "__main__":
    for i, (name, generator, seconds, loop) in enumerate([
        ("chain_link",link,.115,False), ("chains_pavement",chain_run,2.,True),
        ("wiper_sweep",wipers,.98,False), ("exhaust_brake",exhaust_brake,2.,True),
    ]):
        bake(name,generator,seconds,loop,6540+i*83)
