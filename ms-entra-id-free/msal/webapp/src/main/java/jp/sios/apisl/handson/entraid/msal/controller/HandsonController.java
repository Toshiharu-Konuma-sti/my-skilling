package jp.sios.apisl.handson.entraid.msal.controller;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.client.OAuth2AuthorizedClient;
import org.springframework.security.oauth2.client.annotation.RegisteredOAuth2AuthorizedClient;
import org.springframework.security.oauth2.core.oidc.user.OidcUser;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class HandsonController {

	@GetMapping("/hands-on/authorization-code")
	public String authorizationCodeFlow(
			@RegisteredOAuth2AuthorizedClient("my-api-client-u2m") OAuth2AuthorizedClient authorizedClient,
			@AuthenticationPrincipal OidcUser oidcUser,
			Model model) {

		String accessToken = authorizedClient.getAccessToken().getTokenValue();
		String refreshToken = (authorizedClient.getRefreshToken() != null) 
                ? authorizedClient.getRefreshToken().getTokenValue() 
                : "Could not obtain a refresh token (please check if `offline_access` is included in the scope).";
		String idToken = oidcUser.getIdToken().getTokenValue();

		model.addAttribute("accessToken", accessToken);
        model.addAttribute("refreshToken", refreshToken);
        model.addAttribute("idToken", idToken);
        model.addAttribute("userName", oidcUser.getFullName());

		return "authorization-code";
	}

}