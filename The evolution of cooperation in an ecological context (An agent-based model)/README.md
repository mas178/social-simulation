# The evolution of cooperation in an ecological context: An agent-based model

- This is the reproduction of the paper "[Pepper, J. W., & Smuts, B. B. (2000). The evolution of cooperation in an ecological context: an agent-based model. Dynamics in Human and Primate Societies: Agent-Based Modeling of Social and Spatial Processes, 45-76.](https://www.researchgate.net/publication/247870731_The_evolution_of_cooperation_in_an_ecological_context_An_agent-based_model)".
- Although I cannot guarantee the accuracy of the details, I was able to confirm the results of all the experiments in the paper.
- The development and execution environment is [Netlogo 6.2](http://ccl.northwestern.edu/netlogo/).

## The Model

### Parameters

|Category|Name|Description|
|---|---|---|
|world|`mode`|"Alarm calling" or "Feeding restraint"|
|agent parameter of cow|`energy`|the energy of a cow|
|global parameter of cow (to be set in UI)|`initial-cows`|initial count of cows <br/>(default: 40)|
||`cooperative-probability`|the ratio of cooperative cows<br/>(default: 0.5)|
||`metabolism`|metabolic cost per time step (default: 2)|
||`reproduction-threshold`|A cow reproduces asexually when its energy is over this threshold.<br/>(default: 100)|
|agent parameter of grass|`grass`|The energy contained in the grass.|
|global parameter of grass (to be set in UI)|`minimal-number-of-grass`|Number of grasses to place in the world.<br/>(default: 500)|
||`patch-width`|The width of a grass cell.<br/>(default: 3)|
||`gap-width`|The gap width of a grass cell.<br/>(default: 2)|
||`max-grass-height`|Limitations of grass growth.<br/>(default: 10)|

### Procedures

|Procedure|Sub-Procedure|Description|
|---|---|---|
|`setup` (execute once first)|`setup-grasses`|Place grasses according to `minimal-number-of-grass`, `patch-width` and `gap-width`.<br/>The initial value of `grass` is random float value from 0 to `max-grass-height`.|
||`setup-cows`|Place cows on grasses. The initial total count of cows is `initial-cows`. The ratio of cooperative cows to the total is `cooperative-probability`.<br/>The initial value of `energy` is random float value from 0 to `reproduction-threshold`.|
|`go` (repeat for each time step)|`attacked`|- When `mode` is "Alarm calling", the cows are attacked by predators.<br/>- The probability that a cow becomes target of predators is 2%.<br/>- Cooperative cows within 5 cells radius of the target are considered alarm callers.<br/>- The probability of a successful predation is `1 / (the count of alarm callers + 1)`<br/>- One randomly selected target and alarm callers is killed.|
||`move`|- Cows examine their current patch and the eight adjacent cells, and from those not occupied by another cow chose the patch containing the largest `grass`.<br/>- If the chosen patch offered enough `grass` to meet their `metabolism`, they move there.<br/>- Otherwise they move instead to a randomly chosen adjacent unoccupied cell.<br/>- Consumes `metabolism` of `energy` regardless of whether it is moving or not.|
||`eat`|- Cows eat grasses.<br/> - When `mode` is "Feeding restraint", the cooperative cows eat 50% of `grass` on a patch and the uncooperative cows eat 99% of `grass`.<br/>- When `mode` is not "Feeding restraint", the cows eat 99% of `grass` on a patch|
||`reproduce`|- If `energy` exceeds `reproduction-threshold`, the cows hatch one cow.<br/>- The initial `energy` of the child is 50.<br/>- The child is placed in the adjacent patch of the parent.|
||`die`|If their `energy` reached zero, they die. They have no lifespan limit.|
||`grow-grass`|- When `mode` is "Feeding restraint", `grass` increases according to the logistic curve. (`grass` <- `grass` + 0.2 * `grass` * (`max-grass-height` - `grass`) / `max-grass-height`)<br/>- When `mode` is not "Feeding restraint", `grass` increases 1 per each time step.<br/>- The upper limit of grass growth is `max-grass-height`.|
