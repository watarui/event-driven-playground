import {
	ApolloClient,
	createHttpLink,
	InMemoryCache,
	split,
} from "@apollo/client";
import { setContext } from "@apollo/client/link/context";
import { GraphQLWsLink } from "@apollo/client/link/subscriptions";
import { getMainDefinition } from "@apollo/client/utilities";
import { createClient } from "graphql-ws";
import { config } from "./config";

// Auth link to add token to requests
const authLink = setContext(async (_, { headers }) => {
	try {
		// Firebase Auth からトークンを取得
		if (typeof window !== "undefined") {
			const { auth } = await import("./firebase");
			const user = auth.currentUser;
			if (user) {
				const token = await user.getIdToken();
				return {
					headers: {
						...headers,
						authorization: `Bearer ${token}`,
					},
				};
			}
		}

		return { headers };
	} catch (error) {
		console.error("Error getting auth token:", error);
		return { headers };
	}
});

const httpLink = createHttpLink({
	uri: config.graphql.httpEndpoint,
});

// WebSocket link for subscriptions
const wsLink =
	typeof window !== "undefined"
		? new GraphQLWsLink(
				createClient({
					url: config.graphql.wsEndpoint,
				}),
			)
		: null;

// Combine auth link with http link
const authenticatedHttpLink = authLink.concat(httpLink);

// Split based on operation type
const splitLink =
	typeof window !== "undefined" && wsLink
		? split(
				({ query }) => {
					const definition = getMainDefinition(query);
					return (
						definition.kind === "OperationDefinition" &&
						definition.operation === "subscription"
					);
				},
				wsLink,
				authenticatedHttpLink,
			)
		: authenticatedHttpLink;

export const apolloClient = new ApolloClient({
	link: splitLink,
	cache: new InMemoryCache(),
	defaultOptions: {
		watchQuery: {
			fetchPolicy: "cache-and-network",
		},
	},
});
