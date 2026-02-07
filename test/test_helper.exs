ExUnit.start()

# Define mocks
Mox.defmock(Clawbreaker.MockClient, for: Clawbreaker.ClientBehaviour)
