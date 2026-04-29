package jp.sios.apisl.handson.entraid.msal.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.client.OAuth2AuthorizeRequest;
import org.springframework.security.oauth2.client.OAuth2AuthorizedClient;
import org.springframework.security.oauth2.client.OAuth2AuthorizedClientManager;
import org.springframework.security.oauth2.client.annotation.RegisteredOAuth2AuthorizedClient;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class HandsonController {

	@Autowired
    @Qualifier("m2mAuthorizedClientManager") // メモリ管理側のマネージャーを注入
    private OAuth2AuthorizedClientManager m2mManager;

	@GetMapping("/hands-on/authorization-code")
	public String authorizationCodeFlow(
			@RegisteredOAuth2AuthorizedClient("my-client-u2m") OAuth2AuthorizedClient authorizedClient,
			@AuthenticationPrincipal OidcUser oidcUser,
			Model model) {

		String accessToken = authorizedClient.getAccessToken().getTokenValue();
		String refreshToken = (authorizedClient.getRefreshToken() != null) 
                ? authorizedClient.getRefreshToken().getTokenValue() 
                : "Could not obtain a refresh token (please check if `offline_access` is included in the scope).";
		String idToken = oidcUser.getIdToken().getTokenValue();
		String userName = oidcUser.getFullName();

		model.addAttribute("grantType", "Authorization Code Grant");
		model.addAttribute("accessToken", accessToken);
        model.addAttribute("refreshToken", refreshToken);
        model.addAttribute("idToken", idToken);
        model.addAttribute("userName", userName);

		return "authorization-code";
	}

	@GetMapping("/hands-on/client-credentials")
    public String clientCredentialsFlow(Model model) {

        OAuth2AuthorizeRequest request = OAuth2AuthorizeRequest
                .withClientRegistrationId("my-client-m2m")
                .principal("m2m-system")
                .build();
        OAuth2AuthorizedClient client = m2mManager.authorize(request);

        String accessToken = client.getAccessToken().getTokenValue();
        String refreshToken = (client.getRefreshToken() != null)
                ? client.getRefreshToken().getTokenValue()
                : "Client Credentials flow does not issue refresh tokens.";        
        String idToken = "Client Credentials flow does not issue ID tokens (No user involved).";
		String userName = "System (Application Identity)";

        model.addAttribute("grantType", "Client Credentials Grant");
        model.addAttribute("accessToken", accessToken);
        model.addAttribute("refreshToken", refreshToken);
        model.addAttribute("idToken", idToken);
        model.addAttribute("userName", userName);

        return "client-credentials";
    }
}