ExUnit.start()

# Define mocks
Mox.defmock(Clawbreaker.ClientMock, for: Clawbreaker.Client.Behaviour)
