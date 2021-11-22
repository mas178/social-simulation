import os
import sys
import unittest

import numpy as np

sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

from src.Simulation import Agent, Model


class AgentTestCase(unittest.TestCase):
    def test_deterministic(self):
        agent = Agent(1)
        self.assertEqual(agent.id, 1)
        self.assertFalse(agent.next_is_cooperator)
        self.assertFalse(agent.next_is_punisher)
        self.assertEqual(agent.payoff, 0)

    def test_probabilistic(self):
        agents = [Agent(_id) for _id in range(1000)]
        average_cooperator_rate = float(np.mean([agent.is_cooperator for agent in agents]))
        average_punisher_rate = float(np.mean([agent.is_punisher for agent in agents]))
        self.assertAlmostEqual(average_cooperator_rate, 0.5, delta=0.05)
        self.assertAlmostEqual(average_punisher_rate, 0.5, delta=0.05)


class ModelTestCase(unittest.TestCase):
    def test_neighbours(self):
        agents = [Agent(_id) for _id in range(5)]
        model = Model(agents, g=0.0, p=1.0, a=0.0)
        self.assertSetEqual(set(model.neighbours[0]), {3, 4, 1, 2}, '0 の隣人は 3, 4, 1, 2 であるべきだが、{}'.format(model.neighbours[0]))
        self.assertSetEqual(set(model.neighbours[1]), {4, 0, 2, 3}, '1 の隣人は 4, 0, 2, 3 であるべきだが、{}'.format(model.neighbours[1]))
        self.assertSetEqual(set(model.neighbours[2]), {0, 1, 3, 4}, '2 の隣人は 0, 1, 3, 4 であるべきだが、{}'.format(model.neighbours[2]))
        self.assertSetEqual(set(model.neighbours[3]), {1, 2, 4, 0}, '3 の隣人は 1, 2, 4, 0 であるべきだが、{}'.format(model.neighbours[3]))
        self.assertSetEqual(set(model.neighbours[4]), {2, 3, 0, 1}, '4 の隣人は 2, 3, 0, 1 であるべきだが、{}'.format(model.neighbours[4]))


if __name__ == '__main__':
    unittest.main()
