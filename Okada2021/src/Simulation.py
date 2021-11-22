import itertools
import random as r
from datetime import datetime

import numpy as np


class Agent:
    def __init__(self, _id: int):
        self.id: int = _id
        self.is_cooperator: bool = r.choice([True, False])
        self.is_punisher: bool = r.choice([True, False])
        self.next_is_cooperator: bool = False
        self.next_is_punisher: bool = False
        self.payoff: float = 0.0


class Model:
    def __init__(self, agents: list, g: float, p: float, a: float):
        self.agents = agents
        self.n_size = len(agents)
        self.hop = 2
        self.neighbours = []

        self.g = g
        self.p = p
        self.a = a

        self.b = 2.0
        self.c = 1.0
        self.f = 6.0
        self.s = 3.0

        self.μ = 0.01

        # 10/12受領のコード
        # for i in range(self.n_size):
        #     neighbours = []
        #     for j in range(self.hop * 2 + 1):
        #         neighbours.append((i + j + self.n_size - self.hop) % self.n_size)
        #     self.neighbours.append(neighbours)

        # 11/17受領のコード
        for i in range(self.n_size):
            neighbours = []
            for j in range(self.hop):
                neighbours.append((i - j + self.n_size) % self.n_size)
                neighbours.append((i + j + self.n_size) % self.n_size)
            self.neighbours.append(neighbours)

        # 恐らくこれが正しい (？)
        # for _id in range(self.n_size):
        #     inner_neighbours = []
        #     for _hop in range(self.hop):
        #         _prev = _id - (_hop + 1)
        #         _prev = _prev if _prev >= 0 else (_prev + self.n_size)
        #         inner_neighbours.append(_prev)
        #
        #         _post = _id + (_hop + 1)
        #         _post = _post if _post < self.n_size else (_post - self.n_size)
        #         inner_neighbours.append(_post)
        #     self.neighbours.append(inner_neighbours)

        # debug
        # print(self.neighbours)

    def cooperator_rate(self) -> float:
        return float(np.mean([_a.is_cooperator for _a in self.agents]))

    def punisher_rate(self) -> float:
        return float(np.mean([_a.is_punisher for _a in self.agents]))

    def calc_payoffs(self):
        global_cooperator_rate = self.cooperator_rate()
        global_punisher_rate = self.punisher_rate()

        for agent in self.agents:
            local_cooperator_rate = np.mean([self.agents[_id].is_cooperator for _id in self.neighbours[agent.id]])
            local_punisher_rate = np.mean([self.agents[_id].is_punisher for _id in self.neighbours[agent.id]])

            _global_cooperator_rate = (global_cooperator_rate * self.n_size - int(agent.is_cooperator)) / (
                    self.n_size - 1)
            _global_punisher_rate = (global_punisher_rate * self.n_size - int(agent.is_punisher)) / (self.n_size - 1)

            partner = local_cooperator_rate * (1. - self.g) + _global_cooperator_rate * self.g

            _b = (partner * self.hop * 2 + int(agent.is_cooperator)) / (self.hop * 2 + 1)
            _c = float(agent.is_cooperator)
            _p = int(agent.is_punisher) * (
                    (1. - local_cooperator_rate) * (1. - self.p) + (1. - _global_cooperator_rate) * self.p)
            _f = (1 - agent.is_cooperator) * (local_punisher_rate * (1. - self.p) + _global_punisher_rate * self.p)

            agent.payoff = _b * self.b - _c * self.c - _p * self.s - _f * self.f

    def set_next_strategies(self):
        for agent in self.agents:
            if r.random() < self.μ:
                agent.next_is_cooperator = r.choice([True, False])
                agent.next_is_punisher = r.choice([True, False])
            else:
                y = r.choice([_a for _a in self.agents if _a.id != agent.id]) \
                    if r.random() < self.a else self.agents[r.choice(self.neighbours[agent.id])]
                if y.payoff > agent.payoff:
                    agent.next_is_cooperator = y.is_cooperator
                    agent.next_is_punisher = y.is_punisher
                else:
                    agent.next_is_cooperator = agent.is_cooperator
                    agent.next_is_punisher = agent.is_punisher

    def update_strategies(self):
        for agent in self.agents:
            agent.is_cooperator = agent.next_is_cooperator
            agent.is_punisher = agent.next_is_punisher


def run(n_size: int = 100,
        generation: int = 100,
        trial: int = 100,
        _gs: tuple = (0.0, 0.25, 0.5, 0.75, 1.0),
        _ps: tuple = (0.0, 0.25, 0.5, 0.75, 1.0),
        _as: tuple = (0.0, 0.25, 0.5, 0.75, 1.0),
        file_name: str = 'out/py{}.csv'.format(datetime.now().strftime('%Y%m%d_%H%M%S'))):
    for (g, p, a) in itertools.product(_gs, _ps, _as):
        cooperator_rates = []
        punisher_rates = []
        for t in range(trial):
            agents = [Agent(_id) for _id in range(n_size)]
            model = Model(agents, g, p, a)

            for step in range(generation):
                model.calc_payoffs()
                model.set_next_strategies()
                model.update_strategies()

            cooperator_rates.append(model.cooperator_rate())
            punisher_rates.append(model.punisher_rate())

        csv = ','.join([str(x) for x in [g, p, a, np.mean(cooperator_rates), np.mean(punisher_rates)]])
        print(csv)
        with open(file_name, mode='a') as f:
            f.write(csv + '\n')


if __name__ == "__main__":
    # run(_gs=(0.0,), _ps=(1.0,), _as=(0.0,))
    run()
