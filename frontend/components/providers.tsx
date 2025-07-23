"use client";

import { ApolloProvider } from "@apollo/client";
import { AuthProvider } from "@/contexts/auth-context";
import { apolloClient } from "@/lib/apollo-client";

export function Providers({ children }: { children: React.ReactNode }) {
	return (
		<AuthProvider>
			<ApolloProvider client={apolloClient}>{children}</ApolloProvider>
		</AuthProvider>
	);
}
