# MegaMek Data (C) 2025 by The MegaMek Team is licensed under CC BY-NC-SA 4.0.
# To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/4.0/
#
# NOTICE: The MegaMek organization is a non-profit group of volunteers
# creating free software for the BattleTech community.
#
# MechWarrior, BattleMech, `Mech and AeroTech are registered trademarks
# of The Topps Company, Inc. All Rights Reserved.
#
# Catalyst Game Labs and the Catalyst Game Labs logo are trademarks of
# InMediaRes Productions, LLC.
#
# MechWarrior Copyright Microsoft Corporation. MegaMek Data was created under
# Microsoft's "Game Content Usage Rules"
# <https://www.xbox.com/en-US/developers/rules> and it is not endorsed by or
# affiliated with Microsoft.

MMSVersion: 2
name: Test Scenario V2
planet: Bone Norman

description: >
  This test scenarion is written in V2 YAML

map: Test.board

planetaryconditions:
  light: dusk

factions:
- name: Legion of Vega
  deploy: N
  camo: Clans/Wolf/Alpha Galaxy/Alpha Galaxy.jpg

  units:
  - fullname: Archer ARC-2R
    crew:
      name: Cpt. Frederic Nguyen
      skill: 3/4

  - fullname: Hunchback HBK-4G
    crew:
      name: Cpt. Rhonda Snord
      skill: 4/4

- name: 1st Air Cavalry, Federated Suns
  deploy: "E"
  camo: TestCamo.jpg
  units:
  - fullname: Atlas AS7-D
    crew:
      name: Cpt. Frederic Nguyen
      skill: 3/3

  - fullname: Locust LCT-1M
    crew:
      name: Cpt. Rhonda Snord
      skill: 4/5
